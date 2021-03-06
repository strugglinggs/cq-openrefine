setwd("")
# donnees utilisees par radcan 
# https://ici.radio-canada.ca/nouvelle/814609/punaises-lit-montreal-donnees-arrondissement-probleme-exterminateur-ville-logement-appartement-pauvrete

############################################
# test sur un exemple des donnees initiales
###########################################
donnees_initiales <- read.csv("./declarations-exterminations-punaises-de-lit.csv", header=T)
head(donnees_initiales) # on voit des problemes avec les accents
str(donnees_initiales) # les differentes colonnes sont mal interpretees par defaut
summary_initial <- aggregate(donnees_initiales$NBR_EXTERMIN,
                             list(arrond=donnees_initiales$NOM_ARROND,
                                  date = donnees_initiales$DATE_DECLARATION), mean)
plot(x = summary_initial$date, y = summary_initial$x )
# ca s'affiche moyen

###########################################
# test sur un exemple de donnees nettoyees
###########################################
donnees_clean <- read.csv("./formation_openrefine_punaises_bonifiees.csv", header=T)
head(donnees_clean)

library(ggplot2)
library(plyr)
library(scales)
library(zoo)
library(ggmap)
library(plotly)

str(donnees_clean)

pdf("./graphs.pdf")

### UN APERCU DES DECLARATIONS
summary_clean <- aggregate(donnees_clean$NBR_EXTERMIN,
                             list(arrond=donnees_clean$NOM_ARROND,
                                  date = format(as.Date(donnees_clean$DATE_DECLARATION, format="%Y-%m-%d"),"%Y") ), sum)
ggplot(data=summary_clean, aes(x = date, y = x, color=arrond))+geom_line(group = summary_clean$arrond)+theme(axis.title.x=element_blank(), axis.title.y=element_blank())+
  ggtitle("Exterminations par arrondissement entre 2011 et 2016")

# en 2013
# https://quebec.huffingtonpost.ca/2013/05/14/la-ville-de-montreal-cartographie-les-punaises-de-lit_n_3272529.html
# https://www.lapresse.ca/actualites/grand-montreal/201308/26/01-4683176-punaises-de-lit-cette-annee-cest-lenfer.php

summary_arrond <- aggregate(donnees_clean$NBR_EXTERMIN,
                           list(arrond=donnees_clean$NOM_ARROND), sum)

ggplot(summary_arrond, aes(x = reorder(arrond, x), y = x)) + geom_bar(stat = "identity")+
  theme(axis.text.x = element_text(angle = 60, hjust = 1, vjust = 0.5), axis.title.x=element_blank(), axis.title.y=element_blank())+
  ggtitle("Total des exterminations pour la p�riode 2011-2016")+coord_flip()

# HEATMAP TIME SERIES
# http://margintale.blogspot.in/2012/04/ggplot2-time-series-heatmaps.html

donnees_clean$DATE_DECLARATION <- as.Date(donnees_clean$DATE_DECLARATION)  # format date
donnees_clean$ANNEE <- format(as.Date(donnees_clean$DATE_DECLARATION, format="%Y-%m-%d"),"%Y")
donnees_clean$MOIS <- format(as.Date(donnees_clean$DATE_DECLARATION, format="%Y-%m-%d"),"%m")
calend.donnees <- donnees_clean[, c("ANNEE", "MOIS", "DATE_DECLARATION",
                                   "NBR_EXTERMIN", "NOM_ARROND")]
calend.donnees <- plyr::ddply(calend.donnees, .(MOIS,ANNEE,DATE_DECLARATION), numcolwise(sum))

calend.donnees$date <- as.Date(as.character(calend.donnees$DATE_DECLARATION))
calend.donnees$mois_fact<-factor(calend.donnees$MOIS,
                                 levels=as.character(1:12),
                                 labels=c("Jan","Fev","Mar",
                                          "Avr","Mai","Jun",
                                          "Jul","Aou","Sep",
                                          "Oct","Nov","Dec"),
                                 ordered=TRUE)
calend.donnees$yearmonth <- zoo::as.yearmon(calend.donnees$date)
calend.donnees$yearmonthf <- factor(calend.donnees$yearmonth)
calend.donnees$weekday = as.POSIXlt(as.Date(calend.donnees$date))$wday
calend.donnees$weekday_fact<-factor(calend.donnees$weekday,levels=rev(0:6),
                                    labels=rev(c("Dim", "Lun","Mar",
                                                 "Mer","Jeu",
                                                 "Ven","Sam")),
                                    ordered=TRUE)
calend.donnees$yearmonth<-zoo::as.yearmon(calend.donnees$date)
calend.donnees$yearmonthf<-factor(calend.donnees$yearmonth)
calend.donnees$week <- as.numeric(format(calend.donnees$date,"%W"))
calend.donnees<-ddply(calend.donnees,.(yearmonthf),transform,
                      monthweek=1+week-min(week))

ggplot(calend.donnees, aes(monthweek, weekday_fact,
                           fill = NBR_EXTERMIN)) +
  geom_tile(colour = "white") +
  facet_grid(ANNEE~mois_fact) +
  scale_fill_gradient(low="green", high="red") +
  labs(x="Semaine du mois",
       y="",
       title = "Calendrier de l'infestation de punaises de lit a Montreal",
       subtitle="En rouge les periodes de forte infestation",
       fill="Logements contamines")

# VISUALISATION SPATIALE PAR ANNEE DES CONTAMINATIONS
spatial_punaises.mtl <- plyr::ddply(donnees_clean, .(ANNEE, LONGITUDE, LATITUDE, NOM_ARROND),
                                    numcolwise(sum) )
boite_contour <- make_bbox(lon =   spatial_punaises.mtl$LONGITUDE,
                           lat =   spatial_punaises.mtl$LATITUDE, f = .1)
pun_map <- get_map(location = boite_contour, maptype = "satellite", source = "google")
ggmap(pun_map) + geom_point(data = spatial_punaises.mtl,
                            mapping = aes(x = LONGITUDE, y = LATITUDE,
                                          color = -log(NBR_EXTERMIN)))+
  facet_wrap(ANNEE~.)

ggplot(donnees_clean, aes(x=elevation, y=NBR_EXTERMIN))+geom_point(position="jitter")
ggplot(donnees_clean, aes(x=elevation, y=NBR_EXTERMIN))+geom_smooth(method="loess")

dev.off()

# VISUALISATION 3D DES DECLARATIONS SELON L'ELEVATION
plot_ly(donnees_clean, x = ~LATITUDE, y = ~LONGITUDE, z = ~elevation, color = ~NBR_EXTERMIN) %>%
  add_markers() %>%
  layout(scene = list(xaxis = list(title = 'Latitude'),
                      yaxis = list(title = 'Longitude'),
                      zaxis = list(title = 'Elevation')))

# VISUALISATION DU NOMBRE DE DECLARATION PAR LOCALISATION
comb_dec <-  aggregate(donnees_clean$NBR_EXTERMIN, 
                                       list(lat=donnees_clean$LATITUDE, long=donnees_clean$LONGITUDE), length)
boite_contour <- make_bbox(lon =   comb_dec$long, 
                           lat =   comb_dec$lat, f = .1)
pun_map <- get_map(location = boite_contour, maptype = "satellite", source = "google")
ggmap(pun_map) + geom_point(data = comb_dec, 
                            mapping = aes(x = long, y = lat,
                                          color = -x, alpha = x))+ggtitle("Nombre de d�clarations dans la m�me zone pour la p�riode 2011-2016")
# quel est ce sac a puces?
comb_dec <- comb_dec[order(comb_dec$x),]
tail(comb_dec)
