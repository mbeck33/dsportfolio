##################################
#
# Author: Matthew Beck
# Purpose: Visualize COVID Cases and Deaths in the US utilizing a Coxcomb Diagram
#
##################################
options(scipen=999)
# Load the proper libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
# Load the Data
fname <- 'https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv'
covid <- read.csv(file=fname, header = T, stringsAsFactors = FALSE)

# Convert Date to Date data type
covid$date <- as.Date(covid$date)
covid_subset <- covid[covid$date==c("2020-01-31","2020-02-28","2020-03-31","2020-04-30",max(covid$date)),]
#covid$month <- round.POSIXt(covid$date,units=c("months"))
#Group Data and sum cases and deaths
covid_grouped <- covid%>%group_by(month=floor_date(date, "month"))%>%summarize(cases = sum(cases),deaths=sum(deaths))
covid_grouped <- covid_grouped [covid_grouped $month>="2020-03-01",]
# Set Margins, layout for charts


# Nightingale Chart
w <- covid_grouped$cases
pos <- 0.5 * (cumsum(w) + cumsum(c(0, w[-length(w)])))



p <- ggplot(covid_grouped, aes(x = as.factor(month))) + geom_bar(aes(y = cases), fill = "steelblue", 
                                         stat = "identity") + geom_bar(aes(y = deaths), fill = "red", 
                                                                       stat = "identity")
p
p + coord_polar(theta = "x") + scale_x_continuous(labels = covid_grouped$month, breaks = pos)

p + coord_polar()




# Question 1: How have COVID cases increased over time?
case_by_day <- aggregate(list(cases=covid$cases, deaths =covid$deaths), by = list(date=covid$date), sum)
par(mar = c(6,6,2,2),cex.lab = .8)
line.out <- plot(case_by_day$cases
                 , type = "h"
                 , las = 2
                 , col = "steelblue"
                 , xaxt = "n"
                 , lwd = 3
                 , xlab = ""
                 , ylab = ""
                 , main = "Total confirmed US COVID cases over time (May 11, 2020)")
axis(side = 1, at = 1:length(case_by_day$date), labels = gsub(" ", "\n", names(case_by_day$date)), las = 2)


# Question 2 - Adjusting for volume, when are the largest increases in new cases? 
case_by_day$new_cases <- case_by_day$cases-lag(case_by_day$cases)
case_by_day$new_deaths <- case_by_day$deaths-lag(case_by_day$deaths)
scatter.smooth(case_by_day$date,case_by_day$new_cases
     #,type="l"
     , col="steelblue"
     , pch = 16
     , lwd = 4
     , xlab = "Months (2020)"
     , ylab = "New Cases"
     , main = "New US COVID cases over time (as of May 11, 2020)"
     , lpars = (list(col = "steelblue",lwd=2,lty=2))
     , degree=2
     , span=0.5)
axis(side = 1, at = 1:length(by_date), labels = gsub(" ", "\n", names(by_date)), las = 2)
plot(case_by_day$date,case_by_day$new_cases)+scatter.smooth()
plot(case_by_day$date,case_by_day$new_deaths
    # , type="l"
     , col = "darkred"
     , pch = 16
    , xlab = "Months (2020)"
    , ylab = "New Deaths"
    , main = "New US COVID deaths over time (as of May 11, 2020)")
# Plot both, then use line smoothing and ggplot to get this looking nice
scatter.smooth(case_by_day$date,case_by_day$new_deaths
               #,type="l"
               , col="darkred"
               , pch = 16
               , lwd = 4
               , xlab = "Months (2020)"
               , ylab = "New Deaths"
               , main = "New US COVID deaths over time (as of May 11, 2020)"
               , lpars = (list(col = "darkred",lwd=2,lty=2))
               , degree=2
               , span=0.5)
# Question 3 - How has the rate of new cases and deaths changed month to month?
case_by_day$new_case_perc <- (case_by_day$new_cases/lag(case_by_day$new_cases)*100)-100
case_by_day$new_death_perc <- (case_by_day$new_deaths/ifelse(lag(case_by_day$new_deaths)==0,1,lag(case_by_day$new_deaths))*100)-100

covid_new_rate_averages <- case_by_day%>%group_by(month=floor_date(date, "month"))%>%summarize(avg_new_case = mean(new_case_perc),avg_new_deaths=mean(new_death_perc))
covid_new_rate_averages <- covid_new_rate_averages[covid_new_rate_averages$month>="2020-03-01",]
covid_new_rate_averages$avg_new_case <-round(covid_new_rate_averages$avg_new_case,0) 
covid_new_rate_averages$avg_new_deaths <-round(covid_new_rate_averages$avg_new_deaths,0) 
cnra <- pivot_longer(covid_new_rate_averages,-month)
cnra$month_num=month(cnra$month)
# Second Visualization - Show the modern approach to this question
ggplot(cnra) + aes(fill = name, x = reorder(month,-month_num), y = value) +
  geom_bar(stat = "identity", position = "dodge") + 
  scale_fill_manual(values = c("steelblue", "darkred")) + 
  geom_text(aes(label=value), position=position_dodge(width=0.9), vjust=-0.25) +
  coord_flip() +
  ggtitle("Average Daily % of New COVID Cases, Deaths by Month") +
  theme_void()

