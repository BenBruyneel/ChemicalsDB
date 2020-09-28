# code for user interface for the excel sheet with our inventory of chemicals
# developed privately by B. Bruyneel (c) 2020

# libraries needed by the application
library(shiny)
library(shinydashboard)
library(DT)
library(openxlsx)
library(dplyr)
library(stringr)
library(tools)

# config.data has the location & names of the sheets needed/used in the application
# [1] = main database, [2] = (relative) directory where the sheets are located
# [3] = ordering database, [4] = history database
# read the configuration file
readConfig <- function(fileName = "chemicalDB.cfg"){
    return(readLines(fileName, warn = FALSE))
}

# write the configuration file (not used)
writeConfig <- function(fileName = "chemicalDB.cfg"){
    writeLines(config.data, fileName)
}

# read the configuration for the current session
config.data <- readConfig()

# loads one of the sheets into the application
# note: the file extension is used to determine the type of file
# only excel (xlsx) is used currently, but in an earlier version it worked
# also with comma separated files (csv)
chemicalsLoad <- function(dirName = config.data[2],fileName = config.data[1]){
    last4 <- toupper(file_ext(fileName))
    if (last4 == "CSV"){
        chems <- read.csv(paste(c(dirName,"/",fileName), collapse = ""), stringsAsFactors = FALSE,
                          header = TRUE, colClasses = "character")
    } else {
        # if not csv, then is excel file
        wb1All <- loadWorkbook(paste(c(dirName,"/",fileName), collapse = ""))
        chems <- read.xlsx(xlsxFile = wb1All, sheet = "Chemicals", rowNames = FALSE)
        chems %>% mutate_all(as.character)
    }
    return(chems)
}

# saves one of the sheets in the application
# note: the file extension is used to determine the type of file
# only excel (xlsx) is used currently, but in an earlier version it worked
# also with comma separated files (csv)
# note: in this case the directory name must be in fileName!!
chemicalsSave <- function(fileName,chemical.data){
    last4 <- toupper(file_ext(fileName))
    if (last4 == "CSV"){
        write.csv(chemical.data, file = fileName, row.names = FALSE)
    } else {
        # if not csvm the is excel file
        wb1All <- createWorkbook(creator = "")
        addWorksheet(wb1All,sheetName = "Chemicals")
        writeDataTable(wb1All, "Chemicals", chemical.data)
        saveWorkbook(wb1All,fileName, overwrite = TRUE)
    }
}

# if file for order list doesn't exist, then create and remove doubles
#  = non-unique variable/column combinations of 'order.code' & 'Lotnr
if (!file.exists(paste(c(config.data[2],"/",config.data[3]),collapse = ""))){
    file.copy(from = paste(c(config.data[2],"/",config.data[1]),collapse = ""),
              to = paste(c(config.data[2],"/",config.data[3]),collapse = ""))
    ordering  <- chemicalsLoad(fileName = config.data[3]) %>% distinct(Order.code, Lot.nr, .keep_all = TRUE)
    chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[3]),collapse = ""),
                  chemical.data = ordering)
} else {
    ordering  <- chemicalsLoad(fileName = config.data[3])
}

# load the chemical database into the application
chemicals <- chemicalsLoad()

# prepare the choices for fields Suppliers, Units, etc
allSuppliers <- sort(unique(chemicals$Supplier))
allUnits     <- sort(unique(chemicals$Units))
allCategory  <- sort(unique(chemicals$Category))
allLocation  <- sort(unique(chemicals$Location))

# needed for some of the question/answer logic of the administration page
question <- ""

# save the names of the files in the data directory  for the administration page
filesPresent <- dir(path = config.data[2])

# function to create a data.frame with correct fields/columns
# needs 'stringsAsFactors = FALSE' for R < 4.0
createChemicalTable <- function(
                                Chemical.name = as.character(),
                                SDS.sheet = as.character(),
                                CMR = as.character(),
                                CAS.number = as.character(),
                                Number = as.character(),
                                Amount = as.character(),
                                Units = as.character(),
                                Supplier = as.character(),
                                Order.code = as.character(),
                                Lot.nr = as.character(),
                                Expiry.date = as.character(),
                                Category = as.character(),
                                Location = as.character(),
                                Comments = as.character(),
                                entryDate = as.character(),
                                exitDate = as.character()){
    df <- data.frame(Chemical.name = Chemical.name,
                     SDS.sheet = SDS.sheet,
                     CMR = CMR,
                     CAS.number = CAS.number,
                     Number = Number,
                     Amount = Amount,
                     Units = Units,
                     Supplier = Supplier,
                     Order.code = Order.code,
                     Lot.nr = Lot.nr,
                     Expiry.date = Expiry.date,
                     Category = Category,
                     Location = Location,
                     Comments = Comments,
                     entryDate = entryDate,
                     exitDate = exitDate,
                     stringsAsFactors = FALSE) # in case of R  version < 4.
        return(df)
}

# needed for history file (if doesn't exist)
emptyTable <- createChemicalTable(
    Chemical.name = as.character(NA),
    SDS.sheet = as.character(NA),
    CMR = as.character(NA),
    CAS.number = as.character(NA),
    Number = as.character(NA),
    Amount = as.character(NA),
    Units = as.character(NA),
    Supplier = as.character(NA),
    Order.code = as.character(NA),
    Lot.nr = as.character(NA),
    Expiry.date = as.character(NA),
    Category = as.character(NA),
    Location = as.character(NA),
    Comments = as.character(NA),
    entryDate = as.character(NA),
    exitDate = as.character(NA)
)[-1,]

# in memory table of deleted records (= history)
deletedData <- emptyTable

# if file for history table doesn't exist, then create on disk, otherwise load existing file
if (!file.exists(paste(c(config.data[2],"/",config.data[4]),collapse = ""))){
    chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[4]),collapse = ""),
                  chemical.data = deletedData)
} else {
    deletedData <- chemicalsLoad(fileName = config.data[4])
}

# start of shiny ui
ui <- fluidPage(
    
    shinyjs::useShinyjs(),
    
    titlePanel("Chemicals Laboratory"),
    
    sidebarLayout(
        sidebarPanel(width = 2,
                     HTML('
                     <style type="text/css">
                        .well { background-color: rgba(255,255,255,1);
                                border-style : solid;
                                border-color : rgba(255,255,255,1);}
                     </style>'),
            conditionalPanel('input.dataset === "Database"',
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             checkboxGroupInput("show_cols",
                                                "Show Columns:",
                                                names(chemicals), selected = names(chemicals)[c(1,4,5:7,12:13)])
                             ),
            conditionalPanel('input.dataset === "Edit"',
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             box(actionButton("submit", "Add", class = "btn-primary",
                                              width = "105px"), 
                                 width = "100%", height = "100%"),
                             br(),
                             box(actionButton("save", "Save", class = "btn-primary",
                                              width = "105px"),
                                 width = "100%", height = "100%"),
                             br(),
                             box(actionButton("delete", "Delete", class = "btn-primary",
                                              width = "105px"),
                                 width = "100%", height = "100%"),
                             br(),
                             box(actionButton("clear", "Clear ", class = "btn-primary",
                                              width = "105px"),
                                 width = "100%", height = "100%"),
                             br(),
                             br(),
                             box(textOutput("addStatus"),
                                 width = "100%", height = "100%"),
                             br(),
                             box(textOutput("editStatus"),
                                 width = "100%", height = "100%"),
                             br(),
                             box(textOutput("deleteStatus"),
                                 width = "100%", height = "100%"),
                             hr(),
                             box(
                                 HTML("<b><u>Database</u></b>"),
                                 br(),
                                 br(),
                                 box(actionButton("db_reload"  , "Reload data", class = "btn-primary",
                                                  width = "105px"),
                                     width = "100%", height = "100%"),
                                 br(),
                                 box(actionButton("db_write"   , "Write data", class = "btn-primary" , width = "105px"),
                                     width = "100%", height = "100%"),
                                 width = "100%", height = "100%"),
                             hr()
                             ),
            conditionalPanel('input.dataset === "Modify"'),
            conditionalPanel('input.dataset === "Ordering"',
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             checkboxGroupInput("show_cols_ordering",
                                                "Show Columns:",
                                                names(ordering), selected = names(ordering)[c(1,4,7,8,9,10,11,12,14)]),
                             br(),
                             box(actionButton("order_db_update", "Update", class = "btn-primary",
                                              width = "105px"), 
                                 width = "100%", height = "100%"),
                             br()
            ),
            conditionalPanel('input.dataset === "History"',
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             br(),
                             checkboxGroupInput("show_cols_history",
                                                "Show Columns:",
                                                names(deletedData), selected = names(deletedData)[c(1,4,7,8,9,10,12,14,15,16)])
            ),
            conditionalPanel('input.dataset === "Manual"'),
            # administration page: not available anymore. This was only meant to have some basic interface
            # for when using shiny online (with no direct access to the files. Is not complete, was created
            # and abandoned before history sheet became part of the files/program. Left in the source for
            # future reference/expansion
            # -----
            # conditionalPanel('input.dataset === "Administration"',
            #                  br(),
            #                  br(),
            #                  # box(actionButton("db_reload"  , "reload  ", class = "btn-primary", width = "105px"),
            #                  #     width = "100%", height = "100%"),
            #                  # br(),
            #                  # box(actionButton("db_write"   , "Write   ", class = "btn-primary" , width = "105px"),
            #                  #     width = "100%", height = "100%"),
            #                  # hr(),
            #                  box(actionButton("db_select"  , "Select  ", class = "btn-primary", width = "105px"),
            #                      width = "100%", height = "100%"),
            #                  br(),
            #                  box(downloadButton("db_download", "Download", class = "btn-primary"),
            #                      width = "100%", height = "100%"),
            #                  br(),
            #                  box(fileInput("db_upload","Upload",multiple = FALSE, accept = c("*.csv","*.xlsx"),
            #                            width = "105px"),
            #                      width = "100%", height = "100%"),
            #                  hr(),
            #                  box(actionButton("db_backup"  , "Back Up ", class = "btn-primary", width = "105px"),
            #                      width = "100%", height = "100%"),
            #                  br(),
            #                  box(actionButton("db_delete"  , "Delete  ", class = "btn-primary" , width = "105px"),
            #                      width = "100%", height = "100%"),
            #                  br()
            #                 )
        ),
        mainPanel(width = 10,
            tabsetPanel(
                id = 'dataset',
                tabPanel("Database",
                         br(),
                         dataTableOutput('showTable')),
                tabPanel("Edit",
                         br(),
                         textOutput("whichRow"),
                         br(),
                         div(id = "form",
                             fluidRow(
                                 column(5,
                                        textInput("Chemical.name", "Chemical Name", "", width = "100%")),
                                 column(5,
                                        selectInput("Supplier", "Supplier",choices = allSuppliers,
                                                    width = "100%")
                                        )
                             ),
                             fluidRow(
                                 column(5,
                                        textInput("CAS.number", "CAS Number", "", width = "100%")
                                 ),
                                 column(5,
                                        textInput("Order.code", "Order #","", width = "100%")
                                        )
                             ),
                             fluidRow(
                                 column(5,
                                        selectInput("Category", "Category", choices = allCategory,
                                                    width = "100%")
                                 ),
                                 column(5,
                                        textInput("Lotnr", "Lot #","", width = "100%")
                                        )
                             ),
                             fluidRow(
                                 column(5,
                                        selectInput("SDS.sheet", "SDS sheet", selected = "Available",
                                                    choices = c("Available", "Not Available"), width = "100%")
                                 ),
                                 column(5,
                                        dateInput("Expiry.date", "Expiry Date",format ="yyyy-mm", startview = "month",
                                                  weekstart = 0,language = "en-GB", width = "100%", value = NA)
                                        )
                             ),
                             fluidRow(
                                 column(5,
                                        selectInput("CMR", "CMR", selected = "No", choices = c("No","Yes"), width = "100%")
                                 ),
                                 column(5,
                                        textInput("Number", "Number","", width = "100%")
                                 )
                             ),
                             fluidRow(
                                 column(5,
                                        selectInput("Location", "Location", choices = allLocation,
                                                    width = "100%")
                                 ),
                                 column(5,
                                        textInput("Amount", "Amount","", width = "100%")
                                 )
                             ),
                             fluidRow(
                                 column(5,
                                        textInput("Comment", "Comment", "", width = "100%")
                                ),
                                 column(5,
                                        selectInput("Units", "Units", "",choices = allUnits,
                                                    width = "100%")
                                )
                             ),
                             fluidRow(
                                 column(5,
                                        numericInput("records", "# of records (only for add)",
                                                  value = 1, min = 1, max = NA, step = 1,
                                                  width = "100%")
                                        ),
                                 column(5,
                                        dateInput("enterDate", "Entry Date",format ="yyyy-mm-dd", startview = "month",
                                                  weekstart = 0,language = "en-GB", width = "100%", value = NULL)
                                        )
                             )
                         )
                ),
                tabPanel("Modify",
                         tabsetPanel(
                             id = 'modify',
                             tabPanel('Suppliers',
                                      br(),
                                      fluidRow(
                                          column(5, 
                                                 dataTableOutput('showSuppliers')
                                          ),
                                          column(5,
                                                 br(),
                                                 textInput(inputId = "addSupplierV",
                                                           label = "Add Supplier",
                                                           value = "",
                                                           width = "100%"),
                                                 actionButton("addSupplier", "Add", class = "btn-primary")
                                          )
                                          
                                      )
                             ),
                             tabPanel('Categories',
                                      br(),
                                      fluidRow(
                                          column(5,
                                                 dataTableOutput('showCategories')
                                          ),
                                          column(5,
                                                 br(),
                                                 textInput(inputId = "addCategoryV",
                                                           label = "Add Category",
                                                           value = "",
                                                           width = "100%"),
                                                 actionButton("addCategory", "Add", class = "btn-primary"))
                                      )
                             ),
                             tabPanel('Locations',
                                      br(),
                                      fluidRow(
                                          column(5,
                                                 dataTableOutput('showLocations')
                                          ),
                                          column(5,
                                                 br(),
                                                 textInput(inputId = "addLocationV",
                                                           label = "Add Location",
                                                           value = "",
                                                           width = "100%"),
                                                 actionButton("addLocation", "Add", class = "btn-primary"))
                                      )
                             ),
                             tabPanel("Units",
                                      br(),
                                      fluidRow(
                                          column(5,
                                                 dataTableOutput('showUnits')
                                          ),
                                          column(5,
                                                 br(),
                                                 textInput(inputId = "addUnitV",
                                                           label = "Add Unit",
                                                           value = "",
                                                           width = "100%"),
                                                 actionButton("addUnit", "Add", class = "btn-primary"))
                                      )
                             )
                         )
                         ),
                tabPanel("Ordering",
                         br(),
                         dataTableOutput('orderingTable')),
                tabPanel("History",
                         br(),
                         dataTableOutput('historyTable')),
                tabPanel("Manual",  # essentially a text-only page to serve as a (limited/basic) manual
                         box(
                             br(),br(),HTML("<u><b>Chemicals MS Group</b></u>"),
                             br(),br(),HTML("<b>Database</b>"),
                             br(),br(),HTML("Here you can see the chemicals currently in use/stock. 
                                            Selecting an row will cause the form to be `filled` with
                                            the values in the selected row"),
                             hr(),
                             HTML("<b>Edit</b>"),
                             br(),br(),HTML("This the main page for editing/adding/deleting/etc of
                                            rows. Note: no edit/add/etc is final until the database
                                            is written to disk via the <u><i>Write data</i></u> button. The counters
                                            keep track of how many records have been changed in what way.
                                            If there is a need to discard the changes made, then the <u><i>Reload data
                                            </i></u> button."),
                             br(),br(),HTML("<u><i>Add</i></u> adds the data entered in the form into the database"),
                                  br(),HTML("<u><i>Save</i></u> overwrites the data into a <u><i>selected row</i></u>
                                            in the <u><i>Database</i></u> tab"),
                                  br(),HTML("<u><i>Delete</i></u> is for the deletion of a row (selected in the
                                            <u><i>Database</i></u> tab)."),
                                  br(),HTML("<u><i>Clear</i></u> simply clears the data in the form."),
                             hr(),
                             HTML("<b>Modify</b>"),
                             br(),br(),HTML("Here <i>Suppliers</i>,<i>Categories</i>,<i>Locations</i> & <i>Units</i>
                                            can be added. Important: an added, but not used <i>Supplier</i> (etc) will
                                            be removed on in the next session. If a record exists with that <i>Supplier</i>
                                            then it will remain present."),
                             hr(),
                             HTML("<b>Ordering</b>"),
                             br(),br(),HTML("This database is automatically maintained and updated with new chemicals with
                                            <i>new</i> Order code/Lot number combinations. When the 'main' database gets
                                            written to disk, then the same happens to this table."),
                             br(),br(),HTML("The <u><i>Update</i></u> button is there for the situation when data was
                                            added to the chemical database outside of this interface. If clicked it will
                                            check if there are new Order code/Lot number combinations. Important: after
                                            clicking <i>Update</i>, the database should be written!"),
                             hr(),
                             HTML("<b>History</b>"),
                             br(),br(),HTML("The history database is automatically filled with entries that are deleted
                                            from the main <i>Chemicals</i> database. Within this application it cannot
                                            be edited."),
                             hr(),
                             HTML("<b>Manual</b>"),
                             br(),br(),HTML("Basic instructions on the use of this app."),
                             hr(),
                             # HTML("<b>Administration</b>"),
                             # br(),br(),HTML("This is not available (anymore)"),
                             # hr(),
                             width = "90%", height = "100%")
                         )
                # see earlier comments (not in use, left in for possible future use )
                # tabPanel("Administration",
                #          br(),
                #          textOutput(outputId = "fileName"),
                #          br(),
                #          hr(),
                #          fluidRow(
                #              column(5,
                #                     dataTableOutput("fileList")
                #                     )
                #          ) 
                # )
            )
        )
    )
)

# server part of the shiny app
server <- function(input, output, session) {
    
    rv <- reactiveValues()
    
    # these 3 variables are used to keep track of changes made to the chemicals database
    rv$addCounter    <- 0
    rv$editCounter   <- 0
    rv$deleteCounter <- 0
    
    # the databases that get displayed and changed in memory
    # ONLY when the 'write'  button is clicked are the in memory databases updated and written to disk
    rv$chemicals <- chemicals
    rv$ordering <- ordering
    rv$history <- deletedData
    
    # be able to interactively add Suppliers, Units, etc
    rv$allSuppliers <- sort(unique(chemicals$Supplier))
    rv$allUnits     <- sort(unique(chemicals$Units))
    rv$allCategory  <- sort(unique(chemicals$Category))
    rv$allLocation  <- sort(unique(chemicals$Location))
    
    # the filename of the database --> via the administration page it was possible to change this
    rv$fileName <- config.data[1]
    
    # for the administration page logic, not in use at present
    rv$answer <- FALSE
    
    # administration page, not in use
    rv$filesPresent <- filesPresent
    
    # show the chemicals database and allow searching, selection (1 row at a time) etc
    output$showTable <- renderDataTable({
        DT::datatable(rv$chemicals[, input$show_cols], options = list(lengthMenu = c(25,150,250),
                                                                      pageLength = 25,
                                                                      #ordering = FALSE,
                                                                      orderMulti = TRUE,
                                                                      stateSave = TRUE),
                      selection = list(mode = "single"))#, rownames = FALSE)
    }, server = FALSE)
    
    # for updating interactively
    showTableProxy <- dataTableProxy("showTable")
    
    # next 4 elements are for showing the current Suppliers, Units, etc
    output$showSuppliers <- renderDataTable({
        DT::datatable(data.frame(Suppier = rv$allSuppliers, stringsAsFactors = FALSE),
                      options = list(lengthMenu = c(10,25,100),
                                     pageLength = 10,
                                     ordering = FALSE,
                                     stateSave = FALSE),
                      selection = list(mode = "single"))
    }, server = FALSE)
    
    output$showCategories <- renderDataTable({
        DT::datatable(data.frame(Suppier = rv$allCategory, stringsAsFactors = FALSE),
                      options = list(lengthMenu = c(10,25,100),
                                     pageLength = 10,
                                     ordering = FALSE,
                                     stateSave = FALSE),
                      selection = list(mode = "single"))
    }, server = FALSE)
    
    output$showLocations <- renderDataTable({
        DT::datatable(data.frame(Suppier = rv$allLocation, stringsAsFactors = FALSE),
        options = list(lengthMenu = c(10,25,100),
                       pageLength = 10,
                       ordering = FALSE,
                       stateSave = FALSE),
                      selection = list(mode = "single"))
    }, server = FALSE)
    
    output$showUnits <- renderDataTable({
        DT::datatable(data.frame(Suppier = rv$allUnits, stringsAsFactors = FALSE),
                      options = list(lengthMenu = c(10,25,100),
                                     pageLength = 10,
                                     ordering = FALSE,
                                     stateSave = FALSE),
                      selection = list(mode = "single"))
    }, server = FALSE)
    
    # this is what happens when the add-button in the edit-tab is clicked
    # note: there's no real checks on validity of the data, but it's also
    #       relatively easy to delete/edit records in case of mistakes
    observeEvent(input$submit, {
        for (counter in 1:(input$records)){
            rv$chemicals <- bind_rows(
                rv$chemicals,
                createChemicalTable(
                    Chemical.name = input$Chemical.name,
                    SDS.sheet = input$SDS.sheet,
                    CMR = input$CMR,
                    CAS.number = input$CAS.number,
                    Number = input$Number,
                    Amount =input$Amount,
                    Units = input$Units,
                    Supplier = input$Supplier,
                    Order.code = input$Order.code,
                    Lot.nr = input$Lotnr,
                    Expiry.date = ifelse(identical(input$Expiry.date,NA),"",
                                         gsub("-\\d\\d$","",as.character(input$Expiry.date))),
                    Category = input$Category,
                    Location = input$Location,
                    Comments = input$Comment,
                    entryDate = ifelse(identical(input$enterDate,NA),"",
                                       as.character(input$enterDate)),
                    exitDate = ""
                    )
            )
            rv$addCounter <- rv$addCounter + 1
        }
    })
    
    # elements for the counters on the edit page, they serve to show the edits made to the database
    # in memory. When the database is written to disk, these values a reset
    output$addStatus <- renderText({
        paste(toString(rv$addCounter)," record(s) added", sep = "")
    })
    

    output$editStatus <- renderText({
        paste(toString(rv$editCounter)," record(s) edited", sep = "")
    })

    
    output$deleteStatus <- renderText({
        paste(toString(rv$deleteCounter)," record(s) deleted", sep = "")
    })
    
    # element that shows which row/record in the chemicals table is selected (if any)
    output$whichRow <- renderText({
        paste("Selected row : ",toString(input$showTable_rows_selected[1]), sep = "")
    })
    
    # to clear the row selected (row remains intact, just isn't in 'selected' state anymore)
    clearSelection <- function(){
        showTableProxy %>% selectRows(NULL)
        showTableProxy %>% selectColumns(NULL)
    }
    
    # empties the elements of the form
    clearForm <- function(){
        updateTextInput(session, inputId = "Chemical.name", value = "")
        updateSelectInput(session, inputId = "SDS.sheet", selected = "Available")
        updateSelectInput(session, inputId = "CMR", selected = "No")
        updateTextInput(session, inputId = "CAS.number", value = "")
        updateTextInput(session, inputId = "Number", value = "")
        updateTextInput(session, inputId = "Amount", value = "")
        updateSelectInput(session, inputId = "Units", selected = rv$allUnits[1])
        updateSelectInput(session, inputId = "Supplier", selected = rv$allSuppliers[1])
        updateTextInput(session, inputId = "Order.code", value = "")
        updateTextInput(session, inputId = "Lotnr", value = "")
        updateDateInput(session, inputId = "Expiry/date", value = NA)
        updateSelectInput(session, inputId = "Category", selected = rv$allCategory[1])
        updateSelectInput(session, inputId = "Location", selected = rv$allLocation[1])
        updateTextInput(session, inputId = "Comment", value = "")
        updateNumericInput(session, inputId = "records", value = 1)
        updateDateInput(session, inputId = "enterDate", value = NA)
    }
    
    # what happens when a record/row in the main table (chemicals) is selected:
    # fills the edit-form with the values of the selected row/record
    observeEvent(input$showTable_rows_selected,{
        if (!identical(input$showTable_rows_selected, NULL)){
            updateTextInput(session, inputId = "Chemical.name", 
                            value = rv$chemicals$Chemical.name[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "SDS.sheet", 
                            value = rv$chemicals$SDS.sheet[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "CMR", 
                            value = rv$chemicals$CMR[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "CAS.number", 
                            value = rv$chemicals$CAS.number[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Number", 
                            value = rv$chemicals$Number[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Amount", 
                            value = rv$chemicals$Amount[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Units", 
                            value = rv$chemicals$Units[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Supplier", 
                            value = rv$chemicals$Supplier[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Order.code", 
                            value = rv$chemicals$Order.code[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Lotnr", 
                            value = rv$chemicals$Lot.nr[input$showTable_rows_selected[1]])
            # note trick to prevent having to do (date-)conversions
            updateTextInput(session, inputId = "Expiry.date", 
                            value = rv$chemicals$Expiry.date[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Category", 
                            value = rv$chemicals$Category[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Location", 
                            value = rv$chemicals$Location[input$showTable_rows_selected[1]])
            updateTextInput(session, inputId = "Comment", 
                            value = rv$chemicals$comments[input$showTable_rows_selected[1]])
            # note trick to prevent having to do (date-)conversions
            updateTextInput(session, inputId = "enterDate", 
                            value = rv$chemicals$entryDate[input$showTable_rows_selected[1]])
            
        } else {
            clearForm()
        }
    })
    
    # shows the order database/sheet
    output$orderingTable <- renderDataTable({
        DT::datatable(rv$ordering[, input$show_cols_ordering], options = list(lengthMenu = c(25,150,250),
                                                                              pageLength = 25,
                                                                              #ordering = FALSE,
                                                                              orderMulti = TRUE,
                                                                              stateSave = TRUE),
                      selection = list(mode = "none"))#, rownames = FALSE)
    }, server = FALSE)
    
    # shows the history database/sheet
    output$historyTable <- renderDataTable({
        DT::datatable(rv$history[, input$show_cols_history], options = list(lengthMenu = c(25,150,250),
                                                                              pageLength = 25,
                                                                              #ordering = FALSE,
                                                                              orderMulti = TRUE,
                                                                              stateSave = TRUE),
                      selection = list(mode = "none"))#, rownames = FALSE)
    }, server = FALSE)
    
    # what happens when the clear-button (edit form) is clicked
    observeEvent(input$clear,{
        clearSelection()
        clearForm()
    })
    
    # what happens when a record is first selected, then edited and finally saved:
    # the original record is overwritten
    observeEvent(input$save,{
        if (!identical(input$showTable_rows_selected, NULL)){  # only works if a row/record is selected!
            rv$chemicals[input$showTable_rows_selected[1],] <- createChemicalTable(
                Chemical.name = input$Chemical.name,
                SDS.sheet = input$SDS.sheet,
                CMR = input$CMR,
                CAS.number = input$CAS.number,
                Number = input$Number,
                Amount =input$Amount,
                Units = input$Units,
                Supplier = input$Supplier,
                Order.code = input$Order.code,
                Lot.nr = input$Lotnr,
                Expiry.date = ifelse(identical(input$Expiry.date,NA),"",
                                     gsub("-\\d\\d$","",as.character(input$Expiry.date))),
                Category = input$Category,
                Location = input$Location,
                Comments = input$Comment,
                entryDate = ifelse(identical(input$enterDate,NA),"",
                                   as.character(input$enterDate)),
                exitDate = NA
            )
            rv$editCounter <- rv$editCounter + 1
            clearSelection()
            clearForm()
        }
    })
    
    # what happens when delete button is clicked ,deletes the selected record/row
    observeEvent(input$delete,{
        if (!identical(input$showTable_rows_selected, NULL)){ # only works when a record/row is selected
            temp <- input$showTable_rows_selected[1]
            clearSelection()
            clearForm()
            rv$chemicals[temp,]$exitDate <- strftime(Sys.Date(),format = "%Y-%m-%d", usetz = FALSE)
            rv$history <- bind_rows(rv$history,rv$chemicals[temp,])
            rv$chemicals <- rv$chemicals[-temp,]
            rv$deleteCounter <- rv$deleteCounter + 1
        } else {
            # do nothing
        }
    })
    
    # what happens when the update button in the (ordering tab) is pressed
    # in case the chemicals (or ordering) database is edited outside this application
    # see also manual
    observeEvent(input$order_db_update,{
        currentCode <- chemicals %>% distinct(Order.code, Lot.nr, .keep_all = TRUE)
        # new Order.code's 
        newOrderCodes <- currentCode[!currentCode$Order.code %in% ordering$Order.code,]
        # known Order.code's but unknown Lot.nr's
        newLotnrs <- currentCode[(currentCode$Order.code %in% ordering$Order.code) &
                                     !(currentCode$Lot.nr %in% ordering$Lot.nr),]
        # combine all
        newOrderCodes <- bind_rows(newOrderCodes, newLotnrs) %>% distinct(Order.code, Lot.nr, .keep_all = TRUE)
        if (nrow(newOrderCodes)>0){
            ordering <- bind_rows(ordering, newOrderCodes)
            chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[3]), collapse = ""),
                          ordering)
            rv$ordering <- ordering
        }
    })
    
    # next 4 elements define what happens when a Supplier, Units, etc is added
    observeEvent(input$addSupplier,{
        if (!(nchar(input$addSupplierV) == 0) & !(input$addSupplierV %in% rv$allSuppliers)){
            rv$allSuppliers <- sort(append(rv$allSuppliers, input$addSupplierV))
            updateSelectInput(session, inputId = "Supplier", 
                              choices = rv$allSuppliers)
        } else {
            # do nothing
        }
    })
    
    observeEvent(input$addCategory,{
        if (!(nchar(input$addCategoryV) == 0) & !(input$addCategoryV %in% rv$allCategory)){
            rv$allCategory <- sort(append(rv$allCategory, input$addCategoryV))
            updateSelectInput(session, inputId = "Category", 
                              choices = rv$allCategory)
        } else {
            # do nothing
        }
    })
    
    observeEvent(input$addLocation,{
        if (!(nchar(input$addLocationV) == 0) & !(input$addLocationV %in% rv$allLocation)){
            rv$allLocation <- sort(append(rv$allLocation, input$addLocationV))
            updateSelectInput(session, inputId = "Location", 
                              choices = rv$allLocation)
        } else {
            # do nothing
        }
    })
    
    observeEvent(input$addUnit,{
        if (!(nchar(input$addUnitV) == 0) & !(input$addUnitV %in% rv$allUnits)){
            rv$allUnits <- sort(append(rv$allUnits, input$addUnitV))
            updateSelectInput(session, inputId = "Units", 
                              choices = rv$allUnits)
        } else {
            # do nothing
        }
    })
    
    #  ---- administration page ---- not active !!
    # shows the current database filename
    output$fileName <- renderText({paste("Current database: ",rv$fileName, sep = "")})

    #  ---- administration page ---- not active !!
    # shows files in the current (data-)directory
    output$fileList <- renderDataTable({
        DT::datatable(data.frame(Files = rv$filesPresent, stringsAsFactors = FALSE),
                      options = list(lengthMenu = c(10,25,100),
                                     pageLength = 10,
                                     ordering = FALSE,
                                     stateSave = FALSE),
                      selection = list(mode = "single"))
    }, server = FALSE)
    
    #  ---- administration page ---- not active !!
    # to allow interactivity with fileList
    fileListProxy <- dataTableProxy("fileList")

    #  ---- administration page ---- not active !!
    # to be able to get yes/no questions via modal ui
    yesNoModal <- function(failed = FALSE, ynquestion = ""){
        modalDialog(
            tags$div(ynquestion,
                     tags$br()),
            footer = tagList(
                actionButton("yesNoOk","Ok"),
                modalButton("Cancel"),
            )
        )
    }
    
    # event that invokes the yes/no ui
    observeEvent(input$yesNoOk,{
        rv$answer <- TRUE
        removeModal()
    })

    # question to reset the database in memory (yes/no)
    observeEvent(input$db_reload,{
        question <<- "reset"
        showModal(yesNoModal(ynquestion = "Reset Chemicals Database ?"))
    })
    
    #  ---- administration page ---- not active !!
    # what to do when file is selected from fileList
    observeEvent(input$db_select,{
        if (!identical(input$fileList_rows_selected, NULL)){
            if (!(rv$filesPresent[input$fileList_rows_selected[1]] %in% c(config.data[3], config.data[1]))){
                question <<- "select"
                showModal(yesNoModal(ynquestion = paste(c("Load ",rv$filesPresent[input$fileList_rows_selected[1]],"?"), collapse = "")))
            }
        }
    })
    
    #  ---- administration page ---- not active !!
    # to initiate a back up of the selected file (from fileList)
    observeEvent(input$db_backup,{
        file.copy(from = paste(c(config.data[2],"/",config.data[1]),collapse = ""),
                  to = paste(
                      c(config.data[2],"/",
                        file_path_sans_ext(config.data[1]),
                        gsub(":",".",as.character(Sys.time())),
                        ".",
                        file_ext(config.data[1])), collapse = ""))    
        rv$filesPresent <- dir(path = config.data[2])
    })
    
    #  ---- administration page ---- not active !!
    # to delete a file in the fileList
    observeEvent(input$db_delete,{
        if (!identical(input$fileList_rows_selected, NULL)){
            if (!(rv$filesPresent[input$fileList_rows_selected[1]] %in% c(rv$fileName, config.data[3]))){
                question <<- "delete"
                showModal(yesNoModal(ynquestion = paste(c("Delete ",rv$filesPresent[input$fileList_rows_selected[1]],"?"), collapse = "")))
            }
        }
    })
    
    #  ---- administration page ---- not active !!
    # to allow the upload of a file to the data-directory
    observeEvent(input$db_upload,{
        if (!(input$db_upload$name %in% rv$filesPresent)){
            chemicals.temp <- chemicalsLoad(input$db_upload$datapath)
            chemicalsSave(paste(c(config.data[2],"/",input$db_upload$name), collapse = ""),chemicals.temp)
            rv$filesPresent <- dir(path = config.data[2])
        }
    })
    
    # invokes the yes/no question: should database on disk be overwritten with the database in memory?
    observeEvent(input$db_write,{
        question <<- "write"
        showModal(yesNoModal(ynquestion = "Save Chemicals Database ?"))
    })
    
    #  ---- administration page ---- not active !!
    # allows the download of a file in fileList (select first!)
    output$db_download <- downloadHandler(
        filename = function(){
            paste(c(config.data[2],"/",rv$filesPresent[input$fileList_rows_selected[1]]), collapse = "")
        },
        content = function(file){
            chemicals.temp <- chemicalsLoad(paste(c(config.data[2],"/",rv$filesPresent[input$fileList_rows_selected[1]]), collapse = ""))
            chemicalsSave(file, chemicals.temp)
            rv$filesPresent <- dir(path = config.data[2])
            fileListProxy %>% selectRows(NULL)
            fileListProxy %>% selectColumns(NULL)
            shinyjs::disable(id = "db_download")
        }
    )
    
    #  ---- administration page ---- not active !!
    # (de-)activate buttons on administration page when a file is (de-)selected 
    observeEvent(input$fileList_rows_selected, ignoreNULL = FALSE,{
        if (identical(input$fileList_rows_selected, NULL)){
            setAdminButtons(enable = FALSE)    
        } else {
            setAdminButtons(enable = TRUE)
        }
    })
    
    # logic on what to do with response to (y/n) answer
    observeEvent(rv$answer,{
        if (rv$answer) {
            switch(question,
                   "reset" = {
                       rv$addCounter    <- 0
                       rv$editCounter   <- 0
                       rv$deleteCounter <- 0
                       clearForm()
                       rv$history <- deletedData
                       rv$chemicals <- chemicals
                   },
                   "select" = {
                       config.data[1] <<- rv$filesPresent[input$fileList_rows_selected[1]]
                       chemicals <- chemicalsLoad()
                       rv$fileName <- config.data[1]
                       writeConfig()
                       rv$addCounter    <- 0
                       rv$editCounter   <- 0
                       rv$deleteCounter <- 0
                       clearForm()
                       deletedData <- emptyTable
                       rv$chemicals <- chemicals
                   },
                   "delete" = {
                       tempValue <- file.remove(paste(c(config.data[2],"/",rv$filesPresent[input$fileList_rows_selected[1]]), collapse = ""))
                       rv$filesPresent <- dir(path = config.data[2])
                       fileListProxy %>% selectRows(NULL)
                       fileListProxy %>% selectColumns(NULL)
                   },
                   "write" = {
                       rv$addCounter    <- 0
                       rv$editCounter   <- 0
                       rv$deleteCounter <- 0
                       clearForm()
                       chemicals <- rv$chemicals
                       
                       deletedData <- rv$history
                       chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[4]), collapse = ""), chemical.data = deletedData)
                       
                       currentCode <- chemicals %>% distinct(Order.code, Lot.nr, .keep_all = TRUE)
                       # new Order.code's 
                       newOrderCodes <- currentCode[!currentCode$Order.code %in% ordering$Order.code,]
                       # known Order.code's but unknown Lot.nr's
                       newLotnrs <- currentCode[(currentCode$Order.code %in% ordering$Order.code) &
                                                  !(currentCode$Lot.nr %in% ordering$Lot.nr),]
                       # combine all
                       newOrderCodes <- bind_rows(newOrderCodes, newLotnrs) %>% distinct(Order.code, Lot.nr, .keep_all = TRUE)
                       if (nrow(newOrderCodes)>0){
                           ordering <- bind_rows(ordering, newOrderCodes)
                           chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[3]), collapse = ""),
                                         ordering)
                           rv$ordering <- ordering
                       }
                       chemicalsSave(fileName = paste(c(config.data[2],"/",config.data[1]), collapse = ""),
                                     chemicals)
                   })
            rv$answer <- FALSE
        } else {
            # do nothing
        }
    })
    
    #  ---- administration page ---- not active !!
    # (de-)activate the buttons on the administration page
    setAdminButtons <- function(enable = FALSE){
        if (enable){
            shinyjs::enable(id = "db_download")
            shinyjs::enable(id = "db_select")
            shinyjs::enable(id = "db_delete")
            shinyjs::enable(id = "db_backup")
        } else {
            shinyjs::disable(id = "db_download")
            shinyjs::disable(id = "db_select")
            shinyjs::disable(id = "db_delete")
            shinyjs::disable(id = "db_backup")
        }
    }
    
    #  ---- administration page ---- not active !!
    # set initial status of the buttons on the administration page
    setAdminButtons(enable = FALSE)
    
}

# Run the application 
shinyApp(ui = ui, server = server)