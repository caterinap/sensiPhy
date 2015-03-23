sensiC
======

R package to perform model diagnostic for comparative methods

####Installing sensiC from Github:

```{r}
# First install package `devtools` (you should skip this with you have `devtools`)
install.packages("devtools")

devtools::install_github("paternogbc/sensiC")

# Required packages:
library(caper);library(ggplot2);library(gridExtra)
library(sensiC)
```

Loading and organizing data:
```{r}
data(shorebird)

# Organizing comparative data for pgls:
bird.comp <- comparative.data(shorebird.tree, shorebird.data, Species, 
        vcv=TRUE, vcv.dim=3)
```

Original Linear regression (PGLS):
```{r}
mod0 <- pgls(Egg.Mass ~ M.Mass, data=bird.comp,"ML")
summary(mod0)
```

#### Model diagnostics with sensiC package:

##### Example: Estimating sample size bias with `samp_gls`

```{r}
samp <- samp_gls(Egg.Mass ~ M.Mass,data=bird.comp$data,phy=bird.comp$phy)

# see results:
head(samp$results)

# You can also specify number of simulation and break intervals:
samp2 <- samp_gls(Egg.Mass ~ M.Mass,data=bird.comp$data,phy=bird.comp$phy,
                 times= 50, breaks=c(0.1,.2,.3,.4,.5,.6,.7,.8))
```

##### Example: Estimating influential points and parameter bias with `influ_gls`

```{r}
influ <- influ_gls(Egg.Mass ~ M.Mass,data=bird.comp$data,phy=bird.comp$phy)
# Estimated parameters:
head(influ$results)
# Most influential species:
influ[[5]]
# Check for species with erros erros:
influ$errors
```
### Visualizing Results with `sensi_plot`
```{r}
sensi_plot(samp)
sensi_plot(samp2)
sensi_plot(influ)

```
