#' Influential species detection - Phylogenetic Linear Regression
#'
#' Performs leave-one-out deletion analysis for phylogenetic linear regression,
#' and detects influential species.
#'
#' @param formula The model formula
#' @param data Data frame containing species traits with row names matching tips
#' in \code{phy}.
#' @param phy A phylogeny (class 'phylo') matching \code{data}.
#' @param model The phylogenetic model to use (see Details). Default is \code{lambda}.
#' @param cutoff The cutoff value used to identify for influential species
#' (see Details)
#' @param track Print a report tracking function progress (default = TRUE)
#' @param ... Further arguments to be passed to \code{phylolm}
#' @details
#' This function sequentially removes one species at a time, fits a phylogenetic
#' linear regression model using \code{\link[phylolm]{phylolm}}, stores the
#' results and detects influential species.
#'
#' All phylogenetic models from \code{phylolm} can be used, i.e. \code{BM},
#' \code{OUfixedRoot}, \code{OUrandomRoot}, \code{lambda}, \code{kappa},
#' \code{delta}, \code{EB} and \code{trend}. See ?\code{phylolm} for details.
#'
#' \code{influ_phylm} detects influential species based on the standardised
#' difference in intercept and/or slope when removing a given species compared
#' to the full model including all species. Species with a standardised difference
#' above the value of \code{cutoff} are identified as influential. The default
#' value for the cutoff is 2 standardised differences change.
#'
#' Currently, this function can only implement simple linear models (i.e. \eqn{trait~
#' predictor}). In the future we will implement more complex models.
#'
#' Output can be visualised using \code{sensi_plot}.
#'
#' @return The function \code{influ_phylm} returns a list with the following
#' components:
#' @return \code{cutoff}: The value selected for \code{cutoff}
#' @return \code{formula}: The formula
#' @return \code{full.model.estimates}: Coefficients, aic and the optimised
#' value of the phylogenetic parameter (e.g. \code{lambda}) for the full model
#' without deleted species.
#' @return \code{influential_species}: List of influential species, both
#' based on standardised difference in intercept and in the slope of the
#' regression. Species are ordered from most influential to less influential and
#' only include species with a standardised difference > \code{cutoff}.
#' @return \code{sensi.estimates}: A data frame with all simulation
#' estimates. Each row represents a deleted clade. Columns report the calculated
#' regression intercept (\code{intercept}), difference between simulation
#' intercept and full model intercept (\code{DIFintercept}), the standardised
#' difference (\code{sDIFintercept}), the percentage of change in intercept compared
#' to the full model (\code{intercept.perc}) and intercept p-value
#' (\code{pval.intercept}). All these parameters are also reported for the regression
#' slope (\code{DIFestimate} etc.). Additionally, model aic value (\code{AIC}) and
#' the optimised value (\code{optpar}) of the phylogenetic parameter
#' (e.g. \code{kappa} or \code{lambda}, depending on the phylogenetic model used) are
#' reported.
#' @return \code{data}: Original full dataset.
#' @return \code{errors}: Species where deletion resulted in errors.
#' @author Gustavo Paterno & Gijsbert D.A. Werner
#' @seealso \code{\link[phylolm]{phylolm}}, \code{\link{samp_phylm}},
#' \code{\link{influ_phyglm}}, \code{\link{sensi_plot}}
#' @references Ho, L. S. T. and Ane, C. 2014. "A linear-time algorithm for 
#' Gaussian and non-Gaussian trait evolution models". Systematic Biology 63(3):397-408.
#' @examples 
#' # Load data:
#' data(alien)
#' # run analysis:
#' influ <- influ_phylm(log(gestaLen) ~ log(adultMass), phy = alien$phy[[1]], 
#' data = alien$data)
#' # To check summary results:
#'summary(influ)
#'# Most influential speciesL
#'influ$influential.species
#'# Visual diagnostics
#'sensi_plot(influ)
#'# You can specify which graph and parameter ("estimate" or "intercept") to print: 
#'sensi_plot(influ, param = "estimate", graphs = 2)
#' @export

influ_phylm <- function(formula,data,phy,model="lambda",cutoff=2,track=TRUE,...){
        if(class(formula)!="formula") stop("formula must be class 'formula'")
        if(class(data)!="data.frame") stop("data must be class 'data.frame'")
        if(class(phy)!="phylo") stop("phy must be class 'phylo'")
        if ( (model == "trend") && (ape::is.ultrametric(phy)))
        stop("Trend is unidentifiable for ultrametric trees., see ?phylolm for details")
        else

        # Check match between data and phy 
        data_phy <- match_dataphy(formula, data, phy, ...)
        #Calculates the full model, extracts model parameters
        full.data <- data_phy$data
        phy <- data_phy$phy
        N               <- nrow(full.data)
        mod.0           <- phylolm::phylolm(formula, data=full.data,
                                            model=model,phy=phy)
        intercept.0      <- mod.0$coefficients[[1]]
        estimate.0          <- mod.0$coefficients[[2]]
        pval.intercept.0 <- phylolm::summary.phylolm(mod.0)$coefficients[[1,4]]
        pval.estimate.0     <- phylolm::summary.phylolm(mod.0)$coefficients[[2,4]]
        optpar.0 <- mod.0$optpar
        

        #Creates empty data frame to store model outputs
        sensi.estimates<-
                data.frame("species" =numeric(), "intercept"=numeric(),
                           "DIFintercept"=numeric(),"intercept.perc"=numeric(),
                           "pval.intercept"=numeric(),"estimate"=numeric(),
                           "DIFestimate"=numeric(),"estimate.perc"=numeric(),
                           "pval.estimate"=numeric(),"AIC"=numeric(),
                           "optpar" = numeric())

        #Loops over all species, and removes each one individually
        counter <- 1
        errors <- NULL
        if(track==TRUE) pb <- utils::txtProgressBar(min = 0, max = N, style = 3)
        for (i in 1:N){
                
                crop.data <- full.data[c(1:N)[-i],]
                crop.phy <-  ape::drop.tip(phy,phy$tip.label[i])
                mod=try(phylolm::phylolm(formula, data=crop.data,model=model,
                                         phy=crop.phy),
                        TRUE)
                if(isTRUE(class(mod)=="try-error")) {
                        error <- i
                        names(error) <- rownames(full.data$data)[i]
                        errors <- c(errors,error)
                        next }
                else {  sp                   <- phy$tip.label[i]
                        intercept            <- mod$coefficients[[1]]
                        estimate                <- mod$coefficients[[2]]
                        DIFintercept          <- intercept - intercept.0
                        DIFestimate              <- estimate - estimate.0
                        intercept.perc       <- round((abs(DIFintercept/intercept.0))*100,digits=1)
                        estimate.perc           <- round((abs(DIFestimate/estimate.0))*100,digits=1)
                        pval.intercept       <- phylolm::summary.phylolm(mod)$coefficients[[1,4]]
                        pval.estimate           <- phylolm::summary.phylolm(mod)$coefficients[[2,4]]
                        aic.mod              <- mod$aic
                        if (model == "BM" | model == "trend"){
                            optpar <- NA
                        }
                        if (model != "BM" & model != "trend" ){
                            optpar               <- mod$optpar
                        }

                        if(track==TRUE) utils::setTxtProgressBar(pb, i)
                        # Stores values for each simulation
                        estim.simu <- data.frame(sp, intercept, DIFintercept, intercept.perc,
                                                 pval.intercept, estimate, DIFestimate, estimate.perc,
                                                 pval.estimate, aic.mod, optpar,
                                                 stringsAsFactors = F)
                        sensi.estimates[counter, ]  <- estim.simu
                        counter=counter+1
                }
        }
        if(track==TRUE) on.exit(close(pb))
        #Calculates Standardized DFbeta and DIFintercept
        sDIFintercept <- sensi.estimates$DIFintercept/
                stats::sd(sensi.estimates$DIFintercept)
        sDIFestimate     <- sensi.estimates$DIFestimate/
                stats::sd(sensi.estimates$DIFestimate)

        sensi.estimates$sDIFestimate     <- sDIFestimate
        sensi.estimates$sDIFintercept <- sDIFintercept

        #Creates a list with full model estimates:
        param0 <- list(coef=phylolm::summary.phylolm(mod.0)$coefficients,
                       aic=phylolm::summary.phylolm(mod.0)$aic,
                       optpar=mod.0$optpar)

       #Identifies influencital species (sDF > cutoff) and orders by influence
       reorder.on.estimate         <-sensi.estimates[order(abs(
               sensi.estimates$sDIFestimate),decreasing=T),c("species","sDIFestimate")]
       influ.sp.estimate           <-as.character(reorder.on.estimate$species[abs(
               reorder.on.estimate$sDIFestimate)>cutoff])
       reorder.on.intercept     <-sensi.estimates[order(abs(
               sensi.estimates$sDIFintercept),decreasing=T),c("species","sDIFintercept")]
       influ.sp.intercept       <-as.character(reorder.on.intercept$species[abs(
               reorder.on.intercept$sDIFintercept)>cutoff])

        #Generates output:
        res <- list(call = match.call(),
                    cutoff=cutoff,
                    formula=formula,
                    full.model.estimates=param0,
                    influential.species= list(influ.sp.estimate=influ.sp.estimate,
                                              influ.sp.intercept=influ.sp.intercept),
                    sensi.estimates=sensi.estimates,
                    data=full.data,errors=errors)
        class(res) <- "sensiInflu"
        ### Warnings:
        if (length(res$errors) >0){
                warning("Some species deletion presented errors, please check: output$errors")}
        else {
                res$errors <- "No errors found."
        }

        return(res)

}

