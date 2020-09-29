---


# Chemical DB

---

## <ins>Chemical Database Interface</ins>

In the place that I work the inventory of the chemicals we have is stored in an excel sheet. Maybe not the best idea, but well...  that's what's being used.

To make the management of the database a bit easier I wrote a shiny app which allows editing, adding, deleting etc via (more or less) database like interface. It's also important to know that I could not change the format of the original database, since it had to also remain accessible via excel.

I'm not planning to write a full guide to the app's inner workings, since it's pretty simple. My main goal was to get a bit more experience creating shiny apps, because I expect to be needing them for my own work. That is also the reason that's it's a bit 'messy' in terms of code layoout since I was learning along the way.

Below are a few pictures of the interface.


### Main view of the database

![](img/img001.png)<!-- -->


### Main edit interface

![](img/img002.png)<!-- -->

Note:

There are the usual comments to most functions/code in the app.R script. The database included <ins>chemicals-lab.xlsx</ins> contains only a few (fake) entries as obviously I cannot publish the database from my workplace. An important initial step with the original database was cleanup: getting rid of obvious spelling errors, replacing empty excel cells with empty strings (""), etc, etc. It helps the running of the shiny app more smoothly. Also important is that the app will create two extra excel sheets, namely "order" & "history". The first is meant to keep track of all chemicals we have or once had, but may order again (anything that was ever put on the list is preserved based on order code & lot number). The "history" sheet is simpler: everytime an entry is deleted from the main excel sheet, it then gets added to this sheet. It serves as a sort of historical overview of items we do not have anymore (including lot numbers)

Additonal note:

Originally this was meant to be hosted on a dedicated shiny server at work but this turned out to be a bit problematic, so I decided to use it from the server drives that people in my department have access to anyway. Only thing needed was an installation of R itself and some packages plus a windows shortcut to R telling it to launch the shiny app:

"C:\Program Files\R\R-3.6.3\bin\R.exe" -e "shiny::runApp('N:/Chemical log/application/chemicalDB', launch.browser = TRUE)"

It's far from perfect but works better than working directly with excel. 

Any questions/comments? Let me know...  [Ben Bruyneel](mailto:bruyneel.ben@gmail.com)

---
