# Load packages

library(tidyverse)
library(rvest)
library(plyr)

## Load data

WVS <- read.csv("OL_coefficients.csv")

# Effective no parties

CSES1_2 <- read.csv("cses1_2.csv")
CSES3 <- read.csv(unz("cses3_csv.zip", "cses3.csv"))
CSES4 <- read.csv(unz("cses4_csv.zip", "cses4.csv"))

# Ethic & cultural diversity

wiki_eth <- read_html("https://en.wikipedia.org/wiki/List_of_countries_ranked_by_ethnic_and_cultural_diversity_level")

eth_c <- wiki_eth %>% 
  html_nodes("table.wikitable:nth-child(11)") %>%
  html_table(header = TRUE)
eth_c <- eth_c[[1]]
eth_c <- eth_c[, -1]

# Foreign born pop

OECD_MIGR <- read.csv("foreign_pop.csv", na.strings = c("", "NA", "..", " .."))
names(OECD_MIGR)[2:5] <- substr(names(OECD_MIGR)[2:5], 2, 5)

wiki_migr <- read_html("https://en.wikipedia.org/wiki/List_of_sovereign_states_and_dependent_territories_by_immigrant_population")

un_migr15 <- wiki_migr %>% 
  html_nodes("table.wikitable:nth-child(7)") %>% 
  html_table(header = T)
un_migr15 <- un_migr15[[1]]
un_migr15 <- un_migr15[-1, ]
un_migr15 <- un_migr15[, c(1, 4)]

un_migr05 <- wiki_migr %>% 
  html_nodes("table.wikitable:nth-child(16)") %>% 
  html_table(header = T, fill = T)
un_migr05 <- un_migr05[[1]]
un_migr05 <- un_migr05[-1, ]
un_migr05 <- un_migr05[, c(2, 5)]

# GDP per capita

GDP <- read.csv("gdp_per_cap.csv")

# GINI coefficient

GINI <- read.csv("gini.csv")

# Tertiary education

EDU <- read.csv("tertiary edu.csv")

iban <- read_html("https://www.iban.com/country-codes")
edu_codes <- iban %>% 
  html_nodes("#myTable") %>% 
  html_table(header = T)
edu_codes <- edu_codes[[1]]

# Was communist/fascist

f_com <- read.csv("countries.csv")

#### Clean data ####

# Get dataset w country & year 

wvs <- WVS %>% add_column(Country = substr(as.character(WVS$Country_survey_year), 1, 
                                        nchar(as.character(WVS$Country_survey_year))-5))


wvs <- wvs %>% add_column(Year = substr(as.character(wvs$Country_survey_year), 
                                           nchar(as.character(wvs$Country_survey_year))-3, 
                                           nchar(as.character(wvs$Country_survey_year))))

wvs <- wvs %>% mutate(Year = as.numeric(Year))

## Effective no parties clean dataset

# Select cses vars

cses1_2 <- CSES1_2 %>% select(country, year, enep, enep_c)
cses3 <- CSES3 %>% select(C1006, C1008, C5093, C5094)
cses4 <- CSES4 %>% select(D1006, D1008, D5103, D5104)

# Import & fix cses codes

cses_codes <- read.csv("cses codes.csv")

cses_codes <- cses_codes %>% mutate(code = trimws(as.character(code)))

cses_codes <- cses_codes %>% mutate(country = substr(as.character(cses_codes$code), 7, 
                                                     nchar(as.character(cses_codes$code))))

cses_codes <- cses_codes %>% mutate(code = substr(as.character(cses_codes$code), 1, 4))

cses_codes <- cses_codes %>% mutate(code = as.numeric(code))

# Merge codes into 3 & 4

left_join(cses3, cses_codes, by = c("C1006" = "code")) -> cses3
left_join(cses4, cses_codes, by = c("D1006" = "code")) -> cses4

simpleCap <- function(x) {
  s <- strsplit(x, " ")[[1]]
  paste(toupper(substring(s, 1,1)), substring(s, 2),
        sep="", collapse=" ")
}

cses3[, c(5, 2:4)] -> cses3 
names(cses3) <- names(cses1_2)
cses3 %>% mutate(country = tolower(country)) -> cses3
cses3 %>% mutate(country = sapply(country, simpleCap)) -> cses3

cses4[, c(5, 2:4)] -> cses4
names(cses4) <- names(cses1_2)
cses4 %>% mutate(country = tolower(country)) -> cses4
cses4 %>% mutate(country = sapply(country, simpleCap)) -> cses4

# Combine all cses

cses <- rbind(cses1_2, cses3, cses4)

cses$country[cses$country == "Belgium-Flanders"] <- "Belgium"
cses$country[cses$country == "Belgium-Walloon"] <- "Belgium"
cses$country[cses$country == "Korea, South (Rep.)"] <- "South Korea"
cses$country[cses$country == "United States (2012)*"] <- "United States"

cses <- unique(cses)
names(cses)[1:2] <- c("Country", "Year")

## Immigrant population clean dataset

gather(OECD_MIGR, "Year", "Immigrants", -Country) -> oecd_migr
oecd_migr <- oecd_migr %>% mutate(Country = as.character(Country))
oecd_migr$Country[oecd_migr$Country == "Korea"] <- "South Korea"

un_migr05 <- un_migr05 %>% add_column(Year = 2005, .after = "Country")
un_migr15 <- un_migr15 %>% add_column(Year = 2015, .after = "Country")
names(un_migr15)[3] <- c("Immigrants")

immigr <- rbind(oecd_migr, un_migr05, un_migr15)

# Calculate 2005 averages

filter(immigr, Year == 2005) %>%
  dlply("Country") %>% 
  lapply(function(x) {
    mean(as.numeric(x[[3]]), na.rm = T)
  }) %>% 
  do.call(rbind.data.frame, .) -> immigr_05

names(immigr_05) <- "Immigrants"

immigr_05 <- immigr_05 %>% add_column(Country = rownames(immigr_05), 
                                      .before = "Immigrants") %>% 
  add_column(Year = 2005, .before = "Immigrants")

filter(immigr, Year != 2005) %>% 
  rbind(immigr_05) -> immigr

immigr <- immigr %>% mutate(Year = as.numeric(Year)) %>% 
  mutate(Immigrants = as.numeric(Immigrants))

## Clean gdp dataset

gdp <- select(GDP, Country.Name, X1990:X2017)
names(gdp)[2:29] <- substr(names(gdp)[2:29], 2, 5)
names(gdp)[1] <- "Country"

gdp <- gather(gdp, "Year", "GDP_pc", -Country)

gdp <- gdp %>% mutate(Year = as.numeric(Year)) 

## Clean gini dataset

gini <- dplyr::select(GINI, Country.Name, X1990:X2017)
names(gini)[2:29] <- substr(names(gini)[2:29], 2, 5)
names(gini)[1] <- "Country"

gini <- gather(gini, "Year", "GINI", -Country)

gini <- gini %>% mutate(Year = as.numeric(Year)) 

gini <- gini %>% mutate(GINI = GINI/100)

## Clean edu dataset

edu <- inner_join(EDU, edu_codes, by = c("LOCATION" = "Alpha-3 code"))

edu <- select(edu, Country, TIME, Value)
names(edu)[2:3] <- c("Year", "Education")

edu$Country[edu$Country == "Czechia"] <- "Czech Republic"
edu$Country[edu$Country == "Korea (the Republic of)"] <- "South Korea"
edu$Country[edu$Country == "Netherlands (the)"] <- "Netherlands"
edu$Country[edu$Country == "United States of America (the)"] <- "United States"
edu$Country[edu$Country == "United Kingdom of Great Britain and Northern Ireland (the)"] <- "Great Britain"

uk_edu <- filter(edu, Country == "Great Britain")
uk_edu <- uk_edu %>% mutate(Country = "Northern Ireland")

edu <- rbind(edu, uk_edu)

#### Create full dataset ####

vars <- full_join(cses, immigr) %>% 
  full_join(gdp) %>% 
  full_join(gini) %>% 
  full_join(edu) %>%
  full_join(eth_c) %>% 
  full_join(f_com)

vars_oecd <- vars %>% filter(Country %in% wvs$Country | Country == "United Kingdom")

# Fix UK 

vars_oecd$enep[vars_oecd$Country == "United Kingdom" & vars_oecd$Year == 2015] <-
  vars_oecd$enep[vars_oecd$Country == "Great Britain" & vars_oecd$Year == 2015]

vars_oecd$enep_c[vars_oecd$Country == "United Kingdom" & vars_oecd$Year == 2015] <-
  vars_oecd$enep_c[vars_oecd$Country == "Great Britain" & vars_oecd$Year == 2015]

vars_oecd <- filter(vars_oecd, Country != "Great Britain")
vars_oecd$Country[vars_oecd$Country == "United Kingdom"] <- "Great Britain"

#
  
wvs_full <- full_join(wvs, vars_oecd) 

wvs_full[order(wvs_full$Country, wvs_full$Year), ] %>% 
  dlply("Country") %>% 
  lapply(function(x) {
    fill(x, enep:Education)
  }) %>%
  do.call(rbind.data.frame, .) -> wvs_full

wvs_full <- wvs_full %>% mutate(`Cultural Diversity Index` = 
                                  as.numeric(`Cultural Diversity Index`))

#### Model the coefficients ####

lm(Coefficients ~ enep, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ enep_c, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ Immigrants, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ GINI, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ GDP_pc, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ `Ethnic Fractionalization Index`, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ `Cultural Diversity Index`, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ Education, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ ever_fascist, data = wvs_full) %>% 
  summary()

lm(Coefficients ~ ever_communist, data = wvs_full) %>% 
  summary()

## Model building

library(MASS)

dplyr::select(wvs_full, Coefficients, enep_c:ever_communist) %>% 
  filter(!is.na(Coefficients)) -> reg_vars

vars_narm <- na.omit(reg_vars)

lm(Coefficients ~ ., data = vars_narm) %>% 
  stepAIC(direction = "both") -> fit_narm

summary(fit_narm)
extractAIC(fit_narm)

# US equation

2.2812-6.4860*.405+3.3379*.491-2.5452*.271
.98

2.2812-6.4860*.404+3.3379*.491-2.5452*.271
1.4

#### Visualization ####

library(ggiraph)
library(ggrepel)

imm_plot <- ggplot(aes(x = Immigrants, y = Coefficients, color = Country), data = wvs_full) + 
  geom_smooth(method = "glm", aes(x = Immigrants, y = Coefficients), inherit.aes = F) + 
  geom_point_interactive(aes(tooltip = Country_survey_year), show.legend = F) + 
  geom_label_repel(data = filter(wvs_full, Country == "United States"), 
                  aes(x = Immigrants, y = Coefficients, label = Country_survey_year), 
                  segment.color = "black", box.padding = unit(.35, "lines"), point.padding = unit(.5, "lines"), 
                  arrow = arrow(length = unit(.3, "lines")), size = 2.5) +
  scale_x_continuous("Foreign born population (% of total)", breaks = c(0, 5, 10, 15, 20, 25, 30, 35, 40)) +
  scale_y_continuous("Economic ideology-racial resentment association", breaks = c(-3, -2.5, -2, -1.5, -1, -.5, 0, .5, 1, 1.5, 2, 2.5, 3)) +
  guides(color = F) + coord_cartesian(xlim = c(0, 36), ylim = c(-2.5, 2.5)) + 
  labs(caption = "Linear regression plot") + 
  ggtitle("Foreign Born Population vs. Economic Ideology-Racial Resentment Association") +
  theme(title = element_text(size = 12))

girafe(code = print(imm_plot), width_svg = 10)

# Partial regression plots

wvs_narm <- na.omit(wvs_full)

gini_plot <- ggplot(aes(x = resid(glm(GINI ~ `Ethnic Fractionalization Index` + `Cultural Diversity Index` + ever_communist)), 
                        y = resid(glm(Coefficients ~ `Ethnic Fractionalization Index` + `Cultural Diversity Index` + ever_communist)), 
                        color = Country), data = wvs_narm) + 
  geom_smooth(method = "glm", 
              aes(x = resid(glm(GINI ~ `Ethnic Fractionalization Index` + `Cultural Diversity Index` + ever_communist)), 
                  y = resid(glm(Coefficients ~ `Ethnic Fractionalization Index` + `Cultural Diversity Index` + ever_communist))), 
              inherit.aes = F) + geom_point_interactive(aes(tooltip = Country_survey_year), show.legend = F) + 
  scale_x_continuous("GINI coefficient of inequality (residuals)", breaks = c(-.14, -.07, 0, .07, .14)) +
  scale_y_continuous("Economic-racial ideology association (residuals)", breaks = c(-2.5, -2, -1.5, -1, -.5, 0, .5, 1, 1.5, 2, 2.5)) + 
  labs(caption = "Partial multiple linear regression plot") + 
  ggtitle("Economic Inequality vs. Economic Ideology-Racial Resentment Association") +
  theme(title = element_text(size = 12)) + coord_cartesian(ylim = c(-2.5, 2.5), xlim = c(-.13, .13)) + 
  annotate("label", label = "United States (2006)", x = .015, y = .42, size = 2.8, color = "red") +
  annotate("segment", x = .015, y = .295, xend = 0.028958659, yend = 0.184436352, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))  + 
  annotate("label", label = "United States (2011)", x = .048, y = 1.05, size = 2.8, color = "red") +
  annotate("segment", x = .048, y = .925, xend = 0.027958659, yend = 0.609561928, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))

girafe(code = print(gini_plot), width_svg = 10)

eth_plot <- ggplot(aes(x = resid(glm(`Ethnic Fractionalization Index` ~ GINI + `Cultural Diversity Index` + ever_communist)), 
                        y = resid(glm(Coefficients ~ GINI + `Cultural Diversity Index` + ever_communist)), 
                        color = Country), data = wvs_narm) + 
  geom_smooth(method = "glm", 
              aes(x = resid(glm(`Ethnic Fractionalization Index` ~ GINI + `Cultural Diversity Index` + ever_communist)), 
                  y = resid(glm(Coefficients ~ GINI + `Cultural Diversity Index` + ever_communist))), 
              inherit.aes = F) + geom_point_interactive(aes(tooltip = Country_survey_year), show.legend = F) +
  scale_x_continuous("Ethnic fractionalization index (residuals)", breaks = c(-.25, -.2, -.15, -.1, -.05, 0, .05, .1, .15, .2, .25)) +
  scale_y_continuous("Economic-racial ideology association (residuals)", breaks = c(-2.5, -2, -1.5, -1, -.5, 0, .5, 1, 1.5, 2, 2.5)) + 
  labs(caption = "Partial multiple linear regression plot") + 
  ggtitle("Ethnic Diversity vs. Economic Ideology-Racial Resentment Association") +
  theme(title = element_text(size = 12)) + coord_cartesian(ylim = c(-2.5, 2.5), xlim = c(-.2325, .2325)) + 
  annotate("label", label = "United States (2006)", x = .07, y = 1.1, size = 2.8, color = "red") +
  annotate("segment", x = .07, y = .975, xend = 0.116305718, yend = 0.76047741, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))  + 
  annotate("label", label = "United States (2011)", x = .07, y = 1.5, size = 2.8, color = "red") +
  annotate("segment", x = .07, y = 1.375, xend = 0.116752803, yend = 1.18060926, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))

girafe(code = print(eth_plot), width_svg = 10)

cult_plot <- ggplot(aes(x = resid(glm(`Cultural Diversity Index` ~ GINI + `Ethnic Fractionalization Index` + ever_communist)), 
                       y = resid(glm(Coefficients ~ GINI + `Ethnic Fractionalization Index` + ever_communist)), 
                       color = Country), data = wvs_narm) + 
  geom_point_interactive(aes(tooltip = Country_survey_year)) +
  geom_smooth(method = "glm", 
              aes(x = resid(glm(`Cultural Diversity Index` ~ GINI + `Ethnic Fractionalization Index` + ever_communist)), 
                  y = resid(glm(Coefficients ~ GINI + `Ethnic Fractionalization Index` + ever_communist))), 
              inherit.aes = F) + geom_point_interactive(aes(tooltip = Country_survey_year), show.legend = F) +
  scale_x_continuous("Cultural diversity index (residuals)", breaks = c(-.18, -.12, -.06, 0, .06, .12, .18)) +
  scale_y_continuous("Economic-racial ideology association (residuals)", breaks = c(-2.5, -2, -1.5, -1, -.5, 0, .5, 1, 1.5, 2, 2.5)) + 
  labs(caption = "Partial multiple linear regression plot") + 
  ggtitle("Cultural Diversity vs. Economic Ideology-Racial Resentment Association") +
  theme(title = element_text(size = 12)) + coord_cartesian(ylim = c(-2.5, 2.5), xlim = c(-.168, .168)) + guides(color = F) + 
  annotate("label", label = "United States (2006)", x = -.04, y = .9, size = 2.8, color = "red") +
  annotate("segment", x = -.04, y = .775, xend = -0.081163106, yend = 0.578838971, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))  + 
  annotate("label", label = "United States (2011)", x = -.04, y = 1.4, size = 2.8, color = "red") +
  annotate("segment", x = -.04, y = 1.275, xend = -0.081252982, yend = 0.997707262, size = 0.5, 
           arrow = arrow(length = unit(.2, "cm")))

girafe(code = print(cult_plot), width_svg = 10)
