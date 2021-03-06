## this is a script to infer band-metals from band-numbers in the worn and unworn band datasets

bandTypes <- read.csv("MASTER_band-details.csv", sep = ",")
unwornBands <- read.csv("MASTER_unwornBandMasses.csv", sep = ",")
wornBands <- read.csv("MASTER_wornBandMasses.csv", sep = ",")

bandTypes$DATE_BANDS_IN <- as.Date(bandTypes$DATE_BANDS_IN, format = "%d/%m/%y")
bandTypes$YEAR_IN <- format(bandTypes$DATE_BANDS_IN, "%y")
bandTypes$HI_BAND_FULL <- as.numeric(paste(bandTypes$HI_BAND_FULL))
bandTypes$LO_BAND_FULL <- as.numeric(paste(bandTypes$LO_BAND_FULL))
wornBands$Band_no <- as.numeric(paste(wornBands$Band_no))

issueYear <- c(rep(NA, nrow(unwornBands)))
bandMetal <- c(rep(NA, nrow(unwornBands)))

for (i in 1:nrow(unwornBands)) {
    activeOrder <- subset(bandTypes, bandTypes$LO_BAND_FULL < unwornBands$lookupNum[i] &
                                     bandTypes$HI_BAND_FULL > unwornBands$lookupNum[i])
#    print(nrow(activeOrder))
    if(nrow(activeOrder) == 1) {
        issueYear[i] <- activeOrder$YEAR_IN
        bandMetal[i] <- paste(activeOrder$METAL[1])
    }   
}

unwornBands <- data.frame(unwornBands, issueYear, bandMetal)


issueYear <- c(rep(NA, nrow(wornBands)))
bandMetal <- c(rep(NA, nrow(wornBands)))

for (i in 1:nrow(wornBands)) {
    activeOrder <- subset(bandTypes, bandTypes$LO_BAND_FULL < wornBands$Band_no[i] &
                                     bandTypes$HI_BAND_FULL > wornBands$Band_no[i])
#    print(nrow(activeOrder))
    if(nrow(activeOrder) == 1) {
        issueYear[i] <- activeOrder$YEAR_IN
        bandMetal[i] <- paste(activeOrder$METAL[1])
    }    
}

wornBands <- data.frame(wornBands, issueYear, bandMetal)

write.table(unwornBands, "unwornBands.csv", sep = ",", row.names=FALSE)
write.table(wornBands, "wornBands.csv", sep = ",", row.names=FALSE)

### Here, starting to check the unworn bands for integrity and to get starting mass estimates

unwornData <- read.csv("unwornBands_BACKFILLED.csv", sep = ",")

nrow(unwornData)
unworn <- subset(unwornData, unwornData$bandMetal_BACKFILLED != "NA")

bands <- c(unworn$Band_1, unworn$Band_2, unworn$Band_3, unworn$Band_4, unworn$Band_5)
unworn.longform <- rbind(unworn, unworn, unworn, unworn, unworn)
unworn.longform <- data.frame(unworn.longform, bands)
unworn.longform <- cbind(unworn.longform[,1:8], unworn.longform[,14:20])
unworn.longform <- subset(unworn.longform, unworn.longform$bands != "NA")

pdf("unwornMassByMetal.pdf")
for (s in unique(unworn.longform$Size)) {
    activeFrame <- subset(unworn.longform, unworn.longform$Size == s)
    plot.default(activeFrame$bands ~ activeFrame$bandMetal_BACKFILLED,
                 col = activeFrame$issueYear, main = paste("Size ", s))
}
dev.off()

type <- paste(unworn.longform$bandMetal_BACKFILLED, unworn.longform$Batch)
typeMeans <- tapply(X = unworn.longform$bands, INDEX = type, FUN = mean)
typeMedians <- tapply(X = unworn.longform$bands, INDEX = type, FUN = median)
typesd <- tapply(X = unworn.longform$bands, INDEX = type, FUN = sd)

startByType <- data.frame(typeMeans, typeMedians, typesd)
startByType$type <- row.names(startByType)

write.table(startByType, file = "Table 3.csv", sep = ",", row.names = FALSE)

## Here, relating worn band masses to supplementary data from ABBBS

ABBBS <- read.csv(file = "./Worn-band data, filled from ABBBS/MASTER_wornBands_incompleteDates.csv", sep = ",")

backfill <- read.csv(file = "wornBands_BACKFILLED.csv", sep = ",")
backfill$Band_no <- formatC(backfill$Band_no, width = 8, flag = "0")

names(ABBBS) <- c("Band_no", names(ABBBS)[-1])

comb <- merge(ABBBS, backfill, by = "Band_no")
write.table(comb, file = "fullWornBands.csv", sep = ",", row.names = FALSE)

### Deeper analyses start here! #################################################
library(RColorBrewer)
palette(brewer.pal(8, "Dark2"))
fullBands <- read.csv("fullWornBands.csv")
fullBands$Band_no <- formatC(fullBands$Band_no, width = 8, flag = "0")
fullBands$Batch <- formatC(fullBands$Batch, width = 3, flag = "0")
fullBands <- subset(fullBands,
                    fullBands$ELAPSED_MONTHS !=
                    "Time elapsed cannot be calculated")
banded <- as.Date(fullBands$DATE_BANDED, format = "%d-%b-%Y")
found <- as.Date(fullBands$DATE_RECOVERED, format = "%d-%b-%Y")
# turn a date into a 'monthnumber' relative to an origin
monnb <- function(d) { lt <- as.POSIXlt(as.Date(d, origin="1900-01-01"))
                          lt$year*12 + lt$mon } 
# compute a month difference as a difference between two monnb's
mondf <- function(d1, d2) { monnb(d2) - monnb(d1) }
# take it for a spin
mondf(as.Date("2008-01-01"), Sys.Date())
monthDiffs <- c(rep(NA, length(banded)))
for(i in 1:length(monthDiffs)) {
    monthDiffs[i] <- mondf(banded[i], found[i])
}
fullBands <- data.frame(fullBands, monthDiffs)
type2 <- paste(fullBands$Size, fullBands$bandMetal_BACKFILLED)
fullBands <- data.frame(fullBands, type2)
# fullBands <- subset(fullBands, fullBands$monthDiffs)
fullBands <- subset(fullBands, fullBands$massAsProp != "NA")
fullBands <- subset(fullBands, fullBands$bandMetal_BACKFILLED != "NA")
fullBands <- subset(fullBands, fullBands$monthDiffs >= 0)
fullBands <- subset(fullBands, fullBands$bandMetal_BACKFILLED != "?ML")
fullBands <- droplevels(fullBands)

with(fullBands, plot.default(Mass ~ monthDiffs,
                             col =
                              as.numeric(as.factor(bandMetal_BACKFILLED)),
                             ylab = "Mass (g)",
                             xlab = "Time on bird (months)")
     )

with(fullBands, plot.default(massAsProp ~ monthDiffs,
                             col =
                              as.numeric(as.factor(bandMetal_BACKFILLED)),
                             ylab = "Mass (g)",
                             xlab = "Time on bird (months)")
     )
abline(v = c(0,12,24,36,48,60,72,84,96,108,120,132,144,156,168,180,192,204,216,228,240))

## Plotting all band-sizes together, by metal, with lowess smoother.

pdf("propMassByTime_pooled.pdf", width = 9, height = 6.5)
with(fullBands, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             type = "n", axes = FALSE)
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
## Points
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "AM",
                       col = 1, pch = 1)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "AY",
                       col = 2, pch = 2)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "IN",
                       col = 3, pch = 3)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "ML",
                       col = 4, pch = 4)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "SS",
                       col = 5, pch = 5)
     )
## Lowesses
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "AM"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=1, lwd = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "AY"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=2, lwd = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "IN"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=3, lwd = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "ML"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=4, lwd = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "SS"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=5, lwd = 2)
     )
legend(27*12, 0.6, legend = c("Aluminium", "Alloy", "Incoloy", "Monel", "Stainless"),
       col = c(1,2,3,4,5), pch = c(1,2,3,4,5), cex = 0.8)
dev.off()

## Plotting all AMAY, ML, SSIN, with lowess smoothers.

pdf("propMassByTime_AMAY-ML-SSIN_B&W.pdf", width = 4, height = 7)
par(mfrow = c(3,1), mar = c(4.1, 4.1, 0.5, 0.5))
## AMAY
with(fullBands, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of mass remaining",
                             xlab = "Time on bird (years)",
                             type = "n", axes = FALSE)
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,48), labels = seq(0, 30, 4))
box()

with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "AY",
                       col = "grey70", pch = 2)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "AM",
                       col = "grey25", pch = 1)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "AM"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col="grey25", lwd = 1, lty = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "AY"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col="grey70", lwd = 1, lty = 4)
     )
legend(24*12, 0.6, legend = c("Aluminium", "Alloy"),
       col = c("grey25","grey70"), pch = c(1,2), cex = 0.8)
text(29*12, 1.1, "A")

## ML
with(fullBands, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of mass remaining",
                             xlab = "Time on bird (years)",
                             type = "n", axes = FALSE)
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,48), labels = seq(0, 30, 4))
box()
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "ML",
                       col = "grey25", pch = 4)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "ML"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col="grey25", lwd = 1, lty = 2)
     )
#legend(26*12, 0.6, legend = c("Monel"),
#       col = c(4), pch = c(4), cex = 0.8)
text(29*12, 1.1, "B")

## SSIN
with(fullBands, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of mass remaining",
                             xlab = "Time on bird (years)",
                             type = "n", axes = FALSE)
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,48), labels = seq(0, 30, 4))
box()

with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "SS",
                       col = "grey70", pch = 5)
     )
with(fullBands, points(massAsProp ~ monthDiffs,
                       subset = fullBands$bandMetal_BACKFILLED == "IN",
                       col = "grey25", pch = 3)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "IN"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col="grey25", lwd = 1, lty = 2)
     )
with(subset(fullBands, fullBands$bandMetal_BACKFILLED == "SS"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col="grey70", lwd = 1, lty = 4)
     )
legend(24*12, 0.6, legend = c("Incoloy","Stainless"),
       col = c("grey25","grey70"), pch = c(3,5), cex = 0.8)
text(29*12, 1.1, "C")
dev.off()

## Analysis: for each metal-type, group wear-rates by functional group

ML <- subset(fullBands, fullBands$bandMetal_BACKFILLED == "ML")
ML <- droplevels(ML)
AM <- subset(fullBands, fullBands$bandMetal_BACKFILLED == "AM")
AM <- droplevels(AM)
AY <- subset(fullBands, fullBands$bandMetal_BACKFILLED == "AY")
AY <- droplevels(AY)
IN <- subset(fullBands, fullBands$bandMetal_BACKFILLED == "IN")
IN <- droplevels(IN)
SS <- subset(fullBands, fullBands$bandMetal_BACKFILLED == "SS")
SS <- droplevels(SS)

#### Monel ################################################################
pdf("Monel bands, coloured by band prefix, plotting symbols by species.pdf", width = 9,
    height = 6.5)
with(ML, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(as.factor(Batch)),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Monel Bands, split by species and prefix")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(-1, 0.75,
       legend = c(levels(ML$COMMON), "prefix 050", "prefix 140", "prefix 160", "prefix 161"),
       col = c(rep("black", 8), 1:4)
     , pch = c(1:8, 16,16,16,16), cex = 0.75)
dev.off()

## Notable: within Monel bands, there appears to be high variability in susceptibility
 # to wear by manufacturing batch, even within species.

######### AM ############################################################3
pdf("Aluminium bands, coloured functional group.pdf", width = 9,
    height = 6.5)
with(AM, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(funGroup),
                      pch = as.numeric(funGroup), cex = 1,
                      main = "Aluminium Bands, split by functional group")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(-3, 0.59, legend = c(levels(AM$funGroup)), col = c(1:6), pch = c(1:6), cex = 0.75)

with(subset(AM, AM$funGroup == "Birds of Prey"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=1, lwd = 2)
     )
with(subset(AM, AM$funGroup == "Ducks, Geese, and Swans"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=2, lwd = 2)
     )
with(subset(AM, AM$funGroup == "Other Nonpasserines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=3, lwd = 2)
     )
with(subset(AM, AM$funGroup == "Passerines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=4, lwd = 2)
     )
with(subset(AM, AM$funGroup == "Seabirds"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=5, lwd = 2)
     )
with(subset(AM, AM$funGroup == "Waders, Herons, and Ibises"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=6, lwd = 2)
     )
dev.off()

#### Alloy###########################################################333
pdf("Alloy bands, coloured functional group.pdf", width = 9,
    height = 6.5)
with(AY, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(funGroup),
                      pch = as.numeric(funGroup), cex = 1,
                      main = "Alloy Bands, split by functional group", ylim = c(0.5, 1.15))
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(-3, 0.6, legend = c(levels(AY$funGroup)), col = c(1:3), pch = c(1:3), cex = 0.75)

with(subset(AY, AY$funGroup == "Other Nonpasserines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=1, lwd = 2)
     )
with(subset(AY, AY$funGroup == "Passerines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=2, lwd = 2)
     )
with(subset(AY, AY$funGroup == "Seabirds"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=3, lwd = 2)
     )
dev.off()

#### Incoloy #########################

pdf("Incoloy bands, coloured functional group.pdf", width = 9,
    height = 6.5)
with(IN, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(funGroup),
                      pch = as.numeric(funGroup), cex = 1,
                      main = "Incoloy Bands, split by functional group")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(110, 0.95, legend = c(levels(IN$funGroup)), col = c(1:5), pch = c(1:5), cex = 0.9)

with(subset(IN, IN$funGroup == "Birds of Prey"),
     lines(lowess(monthDiffs, massAsProp, f = 1),
           type = "l", col=1, lwd = 2)
     )
with(subset(IN, IN$funGroup == "Other Nonpasserines"),
     lines(lowess(monthDiffs, massAsProp, f = 1),
           type = "l", col=2, lwd = 2)
     )
with(subset(IN, IN$funGroup == "Passerines"),
     lines(lowess(monthDiffs, massAsProp, f = 1),
           type = "l", col=3, lwd = 2)
     )
with(subset(IN, IN$funGroup == "Seabirds"),
     lines(lowess(monthDiffs, massAsProp, f = 1),
           type = "l", col=4, lwd = 2)
     )
with(subset(IN, IN$funGroup == "Waders, Herons, and Ibises"),
     lines(lowess(monthDiffs, massAsProp, f = 1),
           type = "l", col=5, lwd = 2)
     )
dev.off()

### Stainless ################################################

pdf("Stainless bands, coloured by functional group.pdf", width = 9,
    height = 6.5)
with(SS, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(funGroup),
                      pch = as.numeric(funGroup), cex = 1,
                      main = "Stainless Bands, split by functional group")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(0, 0.82, legend = c(levels(SS$funGroup)), col = c(1:8), pch = c(1:8), cex = 0.7)

with(subset(SS, SS$funGroup == "Birds of Prey"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=1, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Ducks, Geese, and Swans"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=2, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Other Nonpasserines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=3, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Parrots"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=4, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Passerines"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=5, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Rails"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=6, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Seabirds"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=7, lwd = 2)
     )
with(subset(SS, SS$funGroup == "Waders, Herons, and Ibises"),
     lines(lowess(monthDiffs, massAsProp, f = 0.3),
           type = "l", col=8, lwd = 2)
     )
dev.off()

##Seabirds, Rails, and Passerines are all interesting within SS bands - closer looks:

SSSeabirds <- droplevels(subset(SS, SS$funGroup == "Seabirds"))
SSRails <- droplevels(subset(SS, SS$funGroup == "Rails"))
SSPasserines <- droplevels(subset(SS, SS$funGroup == "Passerines"))
SSParrots <- droplevels(subset(SS, SS$funGroup == "Parrots"))
SSHerons <- droplevels(subset(SS, SS$funGroup == "Waders, Herons, and Ibises"))

## SSSeabirds
pdf("Stainless Bands by Species within Seabirds.pdf", width = 9, height = 6.5)
with(SSSeabirds, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(COMMON),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Stainless Bands, split by Species within Seabirds")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(19.5*12, 0.95, legend = c(levels(SSSeabirds$COMMON)), col = c(1:19), pch = c(1:19), cex = 0.7)
dev.off()

## SSRails
pdf("Stainless Bands by Species within Rails", width = 9, height = 6.5)
with(SSRails, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(COMMON),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Stainless Bands, split by Species within Rails")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(0, 0.85, legend = c(levels(SSRails$COMMON)), col = c(1:4), pch = c(1:4), cex = 0.9)
dev.off()

##Passerines

pdf("Stainless Bands by Species within Passerines", width = 9, height = 6.5)
with(SSPasserines, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(COMMON),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Stainless Bands, split by Species within Passerines")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(0, 0.87, legend = c(levels(SSPasserines$COMMON)), col = c(1:13), pch = c(1:13), cex = 0.75)
dev.off()

##Parrots
pdf("Stainless Bands by Species within Parrots", width = 9, height = 6.5)
with(SSParrots, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(COMMON),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Stainless Bands, split by Species within Parrots")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(0, 0.93, legend = c(levels(SSParrots$COMMON)), col = c(1:13), pch = c(1:13), cex = 0.75)
dev.off()

## Herons and waders
pdf("Stainless Bands by Species within Waders, Herons, and Ibises.pdf", width = 9, height = 6.5)
with(SSHerons, plot.default(massAsProp ~ monthDiffs,
                             ylab = "Proportion of estimated starting mass remaining",
                             xlab = "Time on bird (years)",
                             #type = "n",
                             axes = FALSE, col = as.numeric(COMMON),
                      pch = as.numeric(COMMON), cex = 1,
                      main = "Stainless Bands, split by Species within Waders, Herons, and Ibises")
     )
axis(side = 2, las = 1)
axis(side = 1, at = seq(0,370,24), labels = seq(0, 30, 2))
box()
legend(16*12, 0.92, legend = c(levels(SSHerons$COMMON)), col = c(1:10), pch = c(1:10), cex = 0.95)
dev.off()


### For each species within each band-type, calculate the mean wear-rate. Report N alongside.

mostBands <- subset(fullBands, fullBands$monthDiffs > 0)
mostBands <- droplevels(mostBands)

types <- unique(mostBands$sizeMetal)
species <- unique(mostBands$COMMON)
scientifics <- unique(mostBands$SCIENTIFIC)
animals <- data.frame(species, scientifics)
animals <- do.call("rbind", replicate(length(types), animals, simplify = FALSE))
repTypes <- c(rep(NA, nrow(animals)))
for (i in 1:nrow(animals)) {
    repTypes[i] <- as.character(types[ceiling(i / 178)])
}

rateTable <- data.frame(animals, types = repTypes)
rateTable$wearRate <- c(rep(NaN, nrow(rateTable)))
rateTable$N <- c(rep(0, nrow(rateTable)))
rateTable$slope <- c(rep(NaN, nrow(rateTable)))
rateTable$slopeSE <- c(rep(NaN, nrow(rateTable)))
rateTable$slopeT <- c(rep(NaN, nrow(rateTable)))
rateTable$slopeP <- c(rep(NaN, nrow(rateTable)))
rateTable$guild <- c(rep(NA, nrow(rateTable)))  ## adding after Nisbet's review.

for (t in types) {
    activeType <- subset(mostBands, mostBands$sizeMetal == t)
    for (s in species) {
        activeFrame <- subset(activeType, activeType$COMMON == s)
        wearRate <- mean((1-activeFrame$massAsProp) /
                         (activeFrame$monthDiffs/12))
#        wearSD <- stdev((1-activeFrame$massAsProp) /
#                         (as.numeric(activeFrame$ELAPSED_MONTHS)/12))
        N <- nrow(activeFrame)
        guild <- as.character(activeFrame$funGroup[1])
        rateTable[rateTable$species == s & rateTable$types == t, ][,4] <- wearRate
        rateTable[rateTable$species == s & rateTable$types == t, ][,5] <- N
        rateTable[rateTable$species == s & rateTable$types == t, ][,10] <- guild

        if(N > 3 && max(activeFrame$monthDiffs) > 0) {
        wear <- with(activeFrame, lm(massAsProp ~ monthDiffs))
        coefs <- summary(wear)$coefficients
        slopeCoef <- coefs[2,1] * 12
        slopeSE <- coefs[2,2] * 12
        slopeT <- coefs[2,3]
        slopeP <- coefs[2,4]

        rateTable[rateTable$species == s & rateTable$types == t, ][,6] <- slopeCoef
        rateTable[rateTable$species == s & rateTable$types == t, ][,7] <- slopeSE
        rateTable[rateTable$species == s & rateTable$types == t, ][,8] <- slopeT
        rateTable[rateTable$species == s & rateTable$types == t, ][,9] <- slopeP
        }
    }
}
rateTable <- subset(rateTable, rateTable$N != 0)
write.table(rateTable, "rateTablev8.csv", sep = ",", row.names = FALSE)
rateTable$Size <- substr(rateTable$types, nchar(as.character(rateTable$types))-1,
                          nchar(as.character(rateTable$types)))
rateTable$Metal <- substr(rateTable$types, 1,
                          2)

## Funnel plots

# with linear-model data (negative is real wear)
with(subset(rateTable, rateTable$Metal == "AM"), plot.default(slope ~ log(N)))
with(subset(rateTable, rateTable$Metal == "AY"), plot.default(slope ~ log(N)))
with(subset(rateTable, rateTable$Metal == "ML"), plot.default(slope ~ log(N)))
with(subset(rateTable, rateTable$Metal == "IN"), plot.default(slope ~ log(N)))
with(subset(rateTable, rateTable$Metal == "SS"), plot.default(slope ~ log(N)))

# with mean-wear data (positive is real wear)
with(subset(rateTable, rateTable$Metal == "AM"), plot.default(wearRate ~ log(N)))
with(subset(rateTable, rateTable$Metal == "AY"), plot.default(wearRate ~ log(N)))
with(subset(rateTable, rateTable$Metal == "ML"), plot.default(wearRate ~ log(N)))
with(subset(rateTable, rateTable$Metal == "IN"), plot.default(wearRate ~ log(N)))
with(subset(rateTable, rateTable$Metal == "SS"), plot.default(wearRate ~ log(N)))

lit <- read.csv("LiteratureComparisons_LONGFORM.csv", sep = ",")
joined <- data.frame(sauce = c(rep("lit", nrow(lit)), rep("own", nrow(rateTable))),
                     species = c(as.character(lit$Common), as.character(rateTable$species)),
                     scientific = c(as.character(lit$Latin.binomial),
                                    as.character(rateTable$scientifics)),
                     metal = c(as.character(lit$Metal), as.character(rateTable$Metal)),
                     pointWear = c(lit$wearProp, rateTable$wearRate),
                     modelWear = c(0-lit$wearProp, rateTable$slope),
                     N = c(lit$N, rateTable$N),
                     guild = c(as.character(lit$Guild), as.character(rateTable$guild))
                     )

with(subset(joined, rateTable$Metal == "SS"), plot.default(pointWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)

with(subset(joined, joined$metal == "SS"), plot.default(modelWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)
with(subset(joined, joined$metal == "AM"), plot.default(modelWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)
with(subset(joined, joined$metal == "AY"), plot.default(modelWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)
with(subset(joined, joined$metal == "IN"), plot.default(modelWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)
with(subset(joined, joined$metal == "ML"), plot.default(modelWear ~ log(N),
                                                           col = as.numeric(sauce)))
abline(h = 0)

SSIN <- rbind(subset(joined, joined$metal == "SS"), subset(joined, joined$metal == "IN"))
AMAY <- rbind(subset(joined, joined$metal == "AM"), subset(joined, joined$metal == "AY"))
JoML <- subset(joined, joined$metal == "ML")

#pooled funnels
pdf("combinedFunnel_v2_B&W.pdf", height = 7, width = 4)
par(mfrow = c(3,1), mar = c(4.1, 5.1, 0.5, 0.5))
palette(c("grey25", "grey70"))

## AMAY funnel
AMAYlm <- with(AMAY, lm(modelWear ~ sauce, weights = log(N)))
summary(AMAYlm)

#pdf("AMAY funnel.pdf")
with(AMAY, plot.default(modelWear ~ log10(N),col = as.numeric(sauce),
                        pch = as.numeric(sauce),
                        #main = "Aluminium and Alloy wear-rates",
                        ##ylab = "Estimated annual mass change",
                        ylab = "",
                        xlab = expression('log'['10']*'(N)'),
                        xlim = c(0,3.5), ylim = c(-0.11, 0.03), las = 1))
title(ylab = "Estimated annual mass change", line = 3.75)
text(3.45, 0.025, "A") ## AM and AY ('soft') bands
abline(h = 0, col = rgb(0.5,0.5,0.5, alpha = 0.6))
abline(h = AMAYlm[1]$coefficients[1], col = 1, lwd = 1.5, lty = 4)
abline(h = (AMAYlm[1]$coefficients[1] + AMAYlm[1]$coefficients[2]), col = 2, lwd = 1.5, lty = 2)
abline(v = c(log10(1), log10(10), log10(100), log10(1000)), col = rgb(0.5,0.5,0.5, alpha = 0.6),
       lty = 2)

  ## refer to model coefs directly, so that they update if data are updated.
#dev.off()

## JoML funnel
JoMLlm <- with(JoML, lm(modelWear ~ sauce, weights = log(N)))
summary(JoMLlm)
#pdf("JoML funnel.pdf")
with(JoML, plot.default(modelWear ~ log10(N),col = as.numeric(sauce),
                        pch = as.numeric(sauce),
                        # main = "Monel wear-rates",
                        ## ylab = "Estimated annual mass change",
                        ylab = "",
                        xlab = expression('log'['10']*'(N)'),
                        xlim = c(0,3.5), ylim = c(-0.11, 0.03), las = 1))
title(ylab = "Estimated annual mass change", line = 3.75)
text(3.45, 0.025, "B") ## ML bands
abline(h = 0, col = rgb(0.5,0.5,0.5, alpha = 0.6))
abline(h = JoMLlm[1]$coefficients[1], col = 1, lwd = 1.5, lty = 4)
abline(h = (JoMLlm[1]$coefficients[1] + JoMLlm[1]$coefficients[2]), col = 2, lwd = 1.5, lty = 2)
abline(v = c(log10(1), log10(10), log10(100), log10(1000)), col = rgb(0.5,0.5,0.5, alpha = 0.6),
       lty = 2)
#dev.off()

## SSIN funnel
SSINlm <- with(SSIN, lm(modelWear ~ sauce, weights = log(N)))
summary(SSINlm)
#pdf("SSIN funnel.pdf")
with(SSIN, plot.default(modelWear ~ log10(N),col = as.numeric(sauce),
                        pch = as.numeric(sauce),
                        #main = "Stainless and Incoloy wear-rates",
                        ##ylab = "Estimated annual mass change",
                        ylab = "",
                        xlab = expression('log'['10']*'(N)'),
                        xlim = c(0,3.5), ylim = c(-0.11, 0.03), las = 1))
title(ylab = "Estimated annual mass change", line = 3.75)
text(3.45, 0.025, "C") ## SS an IN ('hard') bands
abline(h = 0, col = rgb(0.5,0.5,0.5, alpha = 0.6))
abline(h = SSINlm[1]$coefficients[1], col = 1, lwd = 1.5, lty = 4)
abline(h = (SSINlm[1]$coefficients[1] + SSINlm[1]$coefficients[2]), col = 2, lwd = 1.5, lty = 2)
abline(v = c(log10(1), log10(10), log10(100), log10(1000)), col = rgb(0.5,0.5,0.5, alpha = 0.6),
       lty = 2)
#dev.off()
dev.off()

## Nisbet review: re-run those LMs, accounting for differences in wear between guilds

## AMAY

with(AMAY, xtabs(~sauce+guild))
AMAYlm2 <- with(AMAY, lm(modelWear ~ sauce * guild, weights = log(N)))
summary(AMAYlm2)

## JoML

with(JoML, xtabs(~sauce+guild))
JoMLlm2 <- with(JoML, lm(modelWear ~ sauce * guild, weights = log(N)))
summary(JoMLlm2)

## SSIN

with(SSIN, xtabs(~sauce+guild))
SSINlm2 <- with(SSIN, lm(modelWear~sauce + guild, weights = log(N)))
summary(SSINlm2)

## pooled

with(joined, xtabs(~sauce+guild))
pooledLM <- with(joined, lm(modelWear ~ sauce + metal*guild, weights = log(N)))
summary(pooledLM)  ## use this one.

pooledLM2 <- with(joined, lm(modelWear ~ sauce + metal+guild, weights = log(N)))
summary(pooledLM2) ## probably a less accurate structure (within-metal, wear rates probably
                    # truly differ between guilds: the interaction is probably real),
                    # but the headline story is the same in both model specifications.

## Looking into within-species

bothSources <- subset(joined, joined$species %in% c("Silver Gull",
                                                    "Short-tailed Shearwater")
                      )
bothSources <- bothSources[-6,] ## no literature source with STSW banded with SS.

with(droplevels(bothSources), xtabs(modelWear~species+sauce))
lm3 <- lm(modelWear ~ species+sauce, data = bothSources)
summary(lm3)



### Sorting the table into taxonomic order

taxOrderTab <- read.csv("taxOrders.csv", sep = ",")
taxOrderTab <- taxOrderTab[,c(2, 9)]

unOrdered <- subset(rateTable, c(rateTable$scientifics %in% taxOrderTab$scientifics) == FALSE)
Orderable <- subset(rateTable, c(rateTable$scientifics %in% taxOrderTab$scientifics) == TRUE)

ordered <- merge(Orderable, taxOrderTab)
unOrdered <- data.frame(unOrdered, taxOrder = c(rep(NA, nrow(unOrdered)))
                      )
full <- rbind(ordered, unOrdered)
write.table(full, "orderedRateTable.csv", sep = ",", row.names = FALSE)



####  Cleaning Table Three

tab2 <- fullBands[!duplicated(fullBands$initMass),]
tab2$length <- tab2$InternDiam*pi
tab2$Volume <- tab2$length * tab2$Gauge * tab2$Height

pdf("initial masses by volume v2.pdf")
with(tab2, plot.default(initMass ~ Volume, col = as.numeric(bandMetal_BACKFILLED),
                        ylab = "Initial Mass (g)", xlab = parse(text="Volume ~ (mm ^3)")))

with(subset(tab2, tab2$bandMetal_BACKFILLED == "AM" & tab2$Volume != "NA"),
     lines(lowess(Volume, initMass, f = 0.6),
           type = "l", col=1, lwd = 2)
     )
with(subset(tab2, tab2$bandMetal_BACKFILLED == "AY" & tab2$Volume != "NA"),
     lines(lowess(Volume, initMass, f = 0.6),
           type = "l", col=2, lwd = 2)
     )
with(subset(tab2, tab2$bandMetal_BACKFILLED == "IN" & tab2$Volume != "NA"),
     lines(lowess(Volume, initMass, f = 0.6),
           type = "l", col=3, lwd = 2)
     )
with(subset(tab2, tab2$bandMetal_BACKFILLED == "ML" & tab2$Volume != "NA"),
     lines(lowess(Volume, initMass, f = 0.6),
           type = "l", col=4, lwd = 2)
     )
with(subset(tab2, tab2$bandMetal_BACKFILLED == "SS" & tab2$Volume != "NA"),
     lines(lowess(Volume, initMass, f = 0.6),
           type = "l", col=5, lwd = 2)
     )
legend(225, 15, legend = c("Aluminium", "Alloy", "Incoloy", "Monel", "Stainless"),
       col = c(1,2,3,4,5), pch = c(1,1,1,1,1))
dev.off()

write.table(tab2, file = "Table 2 outs v2.csv", sep = ",", row.names = FALSE)




pdf("bandsByTime.pdf")
for(i in unique(fullBands$type)) {
    activeFrame <- subset(fullBands, fullBands$type == i)
    if(nrow(activeFrame)>=1) {
    with(activeFrame, plot.default(massAsProp ~ monthDiffs,
                                   col = Batch, main = activeFrame$type[1])
         )
    }
}
dev.off()


## Assessing the retained/returned contrast.

retention <- read.csv("unwornBands_LONGFORM.csv", sep = ",")
retention <- subset(retention, retention$measuredMass != "NA"
                    & retention$bandMetal_BACKFILLED != "")
retention <- droplevels(retention)
# retention$type <- paste(retention$bandMetal_BACKFILLED, retention$Batch)
# retention$typeMean <- c(rep(NA, nrow(retention)))
# retention$typeMedian <- c(rep(NA, nrow(retention)))
# retention$propDeviation <- c(rep(NA, nrow(retention)))
# for (i in 1:nrow(retention)) {
#     retention$typeMean[i] <- mean(retention$measuredMass[retention$type == retention$type[i]])
#    retention$typeMedian[i] <- median(retention$measuredMass[retention$type == retention$type[i# ]])
# }
retention$propDeviation <- retention$measuredMass / retention$typeMean

lm1 <- with(retention, lm(propDeviation ~ IssueState))
summary(lm1)

lm2 <- with(retention, lm(propDeviation ~ IssueState * type))
summary(lm2)

library(lme4)
m1 <- with(retention, glm(measuredMass ~ as.factor(Batch) + bandMetal_BACKFILLED + IssueState))
summary(m1)

m2 <- with(retention, lmer(measuredMass ~ IssueState + as.factor(Batch) : bandMetal_BACKFILLED
                           + (1 | as.factor(retention$lookupNum))
                           )
           )
summary(m2)


m3 <- with(retention, lm(measuredMass ~ IssueState + as.factor(Batch) : bandMetal_BACKFILLED
                           + as.factor(retention$lookupNum)
                           )
           )
summary(m3)


## looking up changes in supplier through metal, size, and time

suppliers <- read.csv(file = "BACKFILLED_band-details_v2.1.csv", sep = ",")
xtabs(~suppliers$SUPPLIER+suppliers$SIZE)
xtabs(~suppliers$SUPPLIER+suppliers$METAL)
