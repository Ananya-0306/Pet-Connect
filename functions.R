# Function to add an header
addHeader <- function (..., moreInfoLink = "https://github.com/Emelieh21/pet-connect", 
                       moreInfoText = "About", 
                       logo_src = "https://raw.githubusercontent.com/Emelieh21/pet-connect/master/www/logo-wide.png") { 
  div(tags$header(div(style = "background-color:#00a884;padding:15px;width:105%;margin-left:-1em;margin-right:2em;",
                      tags$img(style = "margin-left:20px", 
                               src = logo_src), 
                      ...)), absolutePanel(top = 35, right = 25, 
                                           tags$a(style = "color:#fff;font-size:23px;font-weight:400;", 
                                                  href = moreInfoLink, target = "_blank", moreInfoText)))
}

# Function to add loadbar
addLoadbar <- function(loadingText = "Loading...", 
                        color = '#b3f51b', 
                        top = "0px", alpha = 1) {
  # some styling stuff to see the green loading bar
  div(class = 'wrapper',
      tags$head(tags$style(type="text/css", paste0("
                       #loadmessage {
                       position: fixed;
                       top: ",top,";
                       left: 0px;
                       width: 100%;
                       padding: 5px 0px 5px 0px;
                       text-align: center;
                       font-weight: bold;
                       font-size: 100%;
                       color: #FFFFFF;
                       background-color: ",paste0("rgba(",paste(c(col2rgb(color),alpha),collapse=","),")"),";
                       z-index: 105;}
      "))),
      conditionalPanel(condition="$('html').hasClass('shiny-busy')",
                       tags$div(loadingText,id="loadmessage")))
}
