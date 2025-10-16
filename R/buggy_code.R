#' GOAL: Calculate average temperature, humidity, and Total Dissolved Solids
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
lettuce = read.csv('lettuce_dataset.csv')

#Select only columns we care about
lettuce = lettuce0[, c(1, 2, 3, 9, 5, 6, 10)]

#convert Date to type Date
lettuce$Date = as.Date(lettuce$Date, format = '%m/%d/%Y')

#group by Plant ID
lettuce_grouped = group_by(lettuce, 'Plant_ID')

#Calculate summary statistics
lettuce_summary = summarize(lettuce_grouped,
                            Maturity = max(Growth_Days),
                            Temp = mean(Temp),
                            Humidity = mean(Humidity),
                            TDS = mean(TDS),
                            pH = mean(pH))

#wide to long for plotting purposes (faceting)
lettuce_plot = pivot_longer(lettuce_summary,
                            c('Humidity', 'TDS', 'pH'),
                            names_to = 'variable',
                            values_to = 'value')


#Plotting Maturity vs. other variables
(var_plot = ggplot(data=lettuce_plot) +
    geom_point(aes(x=value, y=Maturity)) +
    facet_wrap(~variable))


#Plotting Total Disolved Solids over time
(ts_plot = ggplot(data=lettuce) +
    geom_line(aes(x=Date, y=TDS, color=Plant_ID)))


