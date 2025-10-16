
#' GOAL: Calculate average temperature, humidity, pH and Total Dissolved Solids
#' (TDS) for each lettuce plant, along with the amount of time it took for the 
#' plant to mature (Maturity)
#' 
#' Additionally plot Humidity, TDS, and pH time series, along with Maturity vs.
#' temp, humidity, tdm and ph.

# Source Data: https://www.kaggle.com/datasets/jurijsruko/lettuce?select=lettuce_dataset_updated.csv"

#load packages
library('dplyr')
library('tidyr')
library('ggplot2')

#Read in data
lettuce0 = read.csv('data/lettuce_dataset_modified.csv', skip=1)

#Select only columns we care about
lettuce = lettuce0[, c(1, 2, 3, 9, 5, 6, 7)]

#rename columns 
new_names = c('Plant_ID', 'Date', 'Temp', 'Humidity', 'TDS', 'pH', 
              'Growth_Days')
names(lettuce) = new_names

#names/str -> range
lettuce$Date = if_else(grepl('\\/', lettuce$Date),
                       as.Date(lettuce$Date, format = '%m/%d/%Y'),
                       as.Date(lettuce$Date, format='%Y-%m-%d'))

lettuce_grouped = group_by(lettuce, Plant_ID)

lettuce_summary = summarize(lettuce_grouped,
                            Maturity = max(Growth_Days),
                            Temp = mean(Temp),
                            Humidity = mean(Humidity, na.rm=TRUE),
                            TDS = mean(TDS, na.rm=TRUE),
                            pH = mean(pH, na.rm=TRUE))

## group by help file, complete cases
lettuce_summary

lettuce_plot = pivot_longer(lettuce_summary,
                            c('Humidity', 'TDS', 'pH'),
                            names_to = 'variable',
                            values_to = 'value')


(var_plot = ggplot(data=lettuce_plot) +
  geom_point(aes(x=value, y=Maturity)) +
  facet_wrap(~variable, scales='free_x'))



(ts_plot = ggplot(data=lettuce) +
  geom_line(aes(x=Date, y=TDS, group=Plant_ID, color=Plant_ID)))


