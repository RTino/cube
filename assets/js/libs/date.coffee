 Date.prototype.week = (date) ->
     if typeof date != 'undefined'
         date = new Date(date) unless typeof date == 'object'

         y = date.getFullYear()
         m = if date.getMonth().toString().length == 2 then date.getMonth() else '0' + (date.getMonth() + 1)
         d = if date.getDate().toString().length == 2 then date.getDate() else '0' + date.getDate()

         startOfYear = new Date(y, 0, 1)
         firstDay = new Date(y, 0, 1)
         nivelation = if firstDay.getDay() + (firstDay.getDay() > 3) then -4 else 3
         now = new Date(y, m - 1, d)

         Math.ceil((((now - startOfYear) / 86400000) + nivelation) / 7) + 1
     else
         0

 Date.prototype.format = (schema, strDate) ->
     date = new Date(strDate)
     days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
     months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']

     formater =
        d : date.getDate().toString()
        dd: if date.getDate().toString().length > 1 then date.getDate().toString() else '0' + date.getDate()
        m: (date.getMonth() + 1).toString()
        mm: if (date.getMonth() + 1).toString().length > 1 then (date.getMonth() + 1).toString() else '0' + (date.getMonth() + 1)
        yy: "'" + date.getFullYear().toString().substring(2)
        yyyy: date.getFullYear().toString()
        day: days[date.getDay()]
        month: months[date.getMonth()]
        sd: days[date.getDay()].substring(0,3)
        sm: months[date.getMonth()].substring(0,3)

     schema.split('%').forEach (item) =>
         item = item.replace(new RegExp("[.,-\/]"), '').trim()
         schema = schema.replace(new RegExp('%'+ item, 'g'), formater[item]) if formater.hasOwnProperty(item)

     schema

 Date.prototype.getStartAndEndDateOfWeek = (week, year, schema) ->
      date = new Date()
      year = year || date.getFullYear()
      firstDayOfYear = new Date(year, 0 ,1)
      weekInMilliseconds = (parseInt(week, 10) - 1)  * 604800000
      nivelation = (1 + (-1 * firstDayOfYear.getDay())) * 86400000
      startDate = new Date(firstDayOfYear.getTime() + weekInMilliseconds + nivelation)
      endDate = new Date(firstDayOfYear.getTime() + weekInMilliseconds + nivelation + 518400000)

      if typeof schema != 'undefined'
          startDate = startDate.format(schema, startDate.toISOString())
          endDate = endDate.format(schema, endDate.toISOString())

      { start: startDate, end: endDate }
