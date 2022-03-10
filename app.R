library(shiny)
library(shinyWidgets)
library(shinythemes)
library(auth0)
library(shinyjs)
library(RPostgres)
library(uuid)
library(openssl)
library(qrcode)

source("functions.R")
# options(shiny.port = 8080)
# To retrigger the pet list
values <- reactiveValues(flag_delete = 0)

ui <- fluidPage(theme = shinytheme("flatly"),
                # Make modal dialog a bit wider
                tags$head(tags$style(".modal-dialog {width: 700px}")),
                # Add header with logo & info link
                addHeader(),
                # Add loadbar
                addLoadbar(),
                # Set full screen background image
                setBackgroundImage(src = 'a-dog-and-a-cat-gdfb2fac9d_1920_3.jpg'),
                # Use shinyjs
                useShinyjs(),
                # Button to add your pet ####
                actionButton("add_pet", "Add your pet", icon("plus"), 
                             style="color:#fff;background-color:#00a884;font-size:200%;margin:35px;"),
                uiOutput("pets")
                )
                
server <- function(input, output, session) {
  # =========================== #
  # Pop up window to add pet ####
  # =========================== #
  observeEvent(input$add_pet, {
    print(session$userData$auth0_info)
    showModal(modalDialog(
      title = "Add your pet",
      div(
        # Upload photo ####
        div(style="display: inline-block;vertical-align:top;margin-top:20px;margin-left:10px;", 
            div(style = "display:flexbox", id = "image-container", 
                img(src = "dog-cat-icon-3.jpg", width = 300)),
            fileInput("myFile", "Upload photo (optional)", accept = c('image/png', 'image/jpeg')),
            div(style = "margin-top: -20px"), # Reduce space
            HTML("<em style='font-size: 8px;'>* This will be publicly visible</em>")
        ),
        # Add info ####
        div(style="display: inline-block;vertical-align:top;margin-top:20px; margin-left:20px;", 
            textInput("pet_name","Name: "),
            div(style = "margin-top: -20px"), # Reduce space
            HTML("<em style='font-size: 8px;'>* This will be publicly visible</em>"),
            textAreaInput("pet_info", "Info: "),
            div(style = "margin-top: -20px"), # Reduce space
            HTML("<em style='font-size: 8px;'>* This will be publicly visible</em>"),
            checkboxInput("mobile_notification", "Send mobile notification", value = TRUE),
            uiOutput("phone_number_output"),
            checkboxInput("email_notification", "Send email notification", value = TRUE),
            uiOutput("email_output"),
            div(id = "agree_text", style="width:300px; font-size:12px", HTML('<input type="checkbox" name="checkbox" value="check" id="agree" /> I have read and agree to the Terms and Conditions</br>and Privacy Policy'))
            )
        ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("ok", "Save & generate QR code",
                     style="color:#fff;background-color:#00a884")
      )
    ))
  })
  # React to image file selection ####
  observeEvent(input$myFile, {
    removeUI(
      selector = "#image-container > *"
    )
    inFile <- input$myFile
    if (is.null(inFile)) 
      return()
    b64 <- base64enc::dataURI(file = inFile$datapath, mime = "image/png")
    insertUI(
      selector = "#image-container",
      where = "afterBegin",
      ui = img(src = b64, width = 300)
    )
  })
  # React to phone notification checkbox ####
  observeEvent(input$mobile_notification, {
    output$phone_number_output <- renderUI({
               if (input$mobile_notification) {
                 textInput("phone_number", "Phone number:")
               } else {
                 return(NULL)
               }
    })
  })
  # React to phone notification checkbox ####
  observeEvent(input$email_notification, {
    output$email_output <- renderUI({
      if (input$email_notification) {
        textInput("email", "Email address:")
      } else {
        return(NULL)
      }
    })
  })
  # React to OK button in "Add your pet" ####
  observeEvent(input$ok, {
    # Check if terms and conditions box is checked
    if (input$agree == FALSE) {
        runjs('document.getElementById("agree_text").style.color = "red";') 
    } else {
      # Save data to pets table ####
      con <- RPostgres::dbConnect(RPostgres::Postgres(), dbname = "kindly-possum-2518.defaultdb", 
                                  host = "free-tier5.gcp-europe-west1.cockroachlabs.cloud", 
                                  port = 26257, user = "emelieh21", 
                                  password = readLines("local/pw.txt"))
      dat <- as.data.frame(session$userData$auth0_info$sub, stringsAsFactors = FALSE) 
      names(dat) <- "user_name"
      dat$pet_id <- UUIDgenerate()
      dat$pet_name <- input$pet_name
      dat$pet_info <- input$pet_info
      dat$phone <- input$phone_number
      dat$email <- input$email
      dat$image <- ifelse(is.null(input$myFile), "",
                          base64enc::dataURI(file = input$myFile$datapath, mime = "image/png"))
      dbWriteTable(con, "pets", dat, overwrite = FALSE, append = TRUE)
      dbDisconnect(con)
      
      # Remove popup
      removeModal()
    }
  })
  # ================================ #
  # Show user his or her own pets ####
  # ================================ #
  output$pets <- renderUI({
    print(input$ok) # Reload when new pet is saved
    print(values$flag_delete)
    con <- RPostgres::dbConnect(RPostgres::Postgres(), dbname = "kindly-possum-2518.defaultdb", 
                                host = "free-tier5.gcp-europe-west1.cockroachlabs.cloud", 
                                port = 26257, user = "emelieh21", 
                                password = readLines("local/pw.txt"))
    print(session$userData$auth0_info$sub)
    pets <- dbGetQuery(con, paste0("with t as (
                                        select pet_id, 
                                             count(distinct(session_token)) as scan_count, 
                                             max(time_stamp) as last_scan
                                        from tracking 
                                        group by pet_id
                                   )
                                   select pets.pet_id, pet_name, pet_info, t.scan_count, t.last_scan
                                   from pets 
                                   left join t ON t.pet_id = pets.pet_id
                                   where user_name = '",session$userData$auth0_info$sub,"'"))
    dbDisconnect(con)
    if (nrow(pets) == 0) {
      return(NULL)
    }
    pets_html <- h1("Your pets")
    for (i in c(1:nrow(pets))) {
      pet_id = pets$pet_id[i]
      png(paste0("www/",pet_id,".png"))
      # Generate QR codes ####
      plot(qr_code(paste0("https://emelieh21.shinyapps.io/pet-connect-open/?pet_id=",pets$pet_id[i],"&mode=scanned"), ecl = "Q"))
      dev.off()
      pet_div <- div(style='margin-left:5px;',
        div(style="display: inline-block;vertical-align:top;margin-top:20px; margin-left:20px;", 
            img(src = paste0(pet_id,".png"), width = 150)),
        div(style="display: inline-block;vertical-align:top;margin-top:20px; margin-left:20px; width:400px;", 
            HTML(paste0("<b>Name: </b>", pets$pet_name[i], "</br>",
                        "<b>Info: </b>", pets$pet_info[i]), "</br>",
                        "<b>Last scan: </b><em>", ifelse(is.na(pets$last_scan[i]),
                                                "Not available", as.character(pets$last_scan[i])), "</em></br>",
                        "<b>Total scans: </b>", ifelse(is.na(pets$scan_count[i]), 0,
                                                 as.numeric(pets$scan_count[i])), "</br>"
                 ),
            actionButton(paste0("delete_",pet_id), "Delete", #icon("trash-alt"),
                         style="font-size:65%;padding-top:5px;padding-bottom:5px;padding-left:10px;padding-right:10px;margin-top:10px;"))
        )
      pets_html <- paste(pets_html, pet_div, sep="</br>")
    }
    # React to buttons
    lapply(
      X = 1:nrow(pets),
      FUN = function(i){
        observeEvent(input[[paste0("delete_", pets$pet_id[i])]], {
          print(pets$pet_id[i])
          con <- RPostgres::dbConnect(RPostgres::Postgres(), dbname = "kindly-possum-2518.defaultdb", 
                                      host = "free-tier5.gcp-europe-west1.cockroachlabs.cloud", 
                                      port = 26257, user = "emelieh21", 
                                      password = readLines("local/pw.txt"))
          dbSendQuery(con, paste0("delete from pets where pet_id = '",pets$pet_id[i],"'"))
          message("Pet removed from DB")
          values$flag_delete = values$flag_delete+1
        }, once = TRUE, autoDestroy = TRUE, ignoreInit = TRUE)
      }
    )
    return(div(style="margin-left:35px;",HTML(pets_html)))
  })
  
}


shinyAppAuth0(ui, server, config_file = 'local/_auth0.yml')
