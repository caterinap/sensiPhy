#' Phylogenetic uncertainty - Phylogenetic Logistic Regression
#'
#' Performs Phylogenetic logistic regression evaluating
#' uncertainty in trees topology.
#'
#' @param formula The model formula
#' @param data Data frame containing species traits with species as row names.
#' @param phy A phylogeny (class 'multiPhylo', see ?\code{ape}).
#' @param n.tree Number of times to repeat the analysis with n different trees picked 
#' randomly in the multiPhylo file.
#' If NULL, \code{n.tree} = 2
#' @param btol Bound on searching space. For details see \code{phyloglm}.
#' @param track Print a report tracking function progress (default = TRUE)
#' @param ... Further arguments to be passed to \code{phyloglm}
#' @details
#' This function fits a phylogenetic logistic regression model using \code{\link[phylolm]{phyloglm}}
#' to n trees, randomly picked in a multiPhylo file.
#'
#' Currently, this function can only implement simple logistic models (i.e. \eqn{trait~
#' predictor}). In the future we will implement more complex models.
#'
#' Output can be visualised using \code{sensi_plot}.
#'
#' @return The function \code{tree_phyglm} returns a list with the following
#' components:
#' @return \code{formula}: The formula
#' @return \code{data}: Original full dataset
#' @return \code{sensi.estimates}: Coefficients, aic and the optimised
#' value of the phylogenetic parameter (e.g. \code{lambda}) for each regression with a 
#' different phylogenetic tree.
#' @return \code{N.obs}: Size of the dataset after matching it with tree tips and removing NA's.
#' @return \code{stats}: Main statistics for model parameters.\code{CI_low} and \code{CI_high} are the lower 
#' and upper limits of the 95% confidence interval.
#' @return \code{all.stats}: Complete statistics for model parameters. \code{sd_intra} is the standard deviation 
#' due to intraspecific variation. \code{CI_low} and \code{CI_high} are the lower and upper limits 
#' of the 95% confidence interval.
#' @author Caterina Penone & Pablo Ariel Martinez
#' @seealso \code{\link[phylolm]{phyloglm}}, \code{\link{sensi_plot}},\code{\link{tree_phylm}}
#' @references 
#' Donoghue, M.J. & Ackerly, D.D. (1996). Phylogenetic Uncertainties and 
#' Sensitivity Analyses in Comparative Biology. Philosophical Transactions:
#'  Biological Sciences, pp. 1241-1249.
#'  
#' Ho, L. S. T. and Ane, C. 2014. "A linear-time algorithm for 
#' Gaussian and non-Gaussian trait evolution models". Systematic Biology 63(3):397-408.
#' @examples 
#'### Simulating Data:
#'set.seed(6987)
#'mphy = rmtree(150, N = 30)
#'x = rTrait(n=1,phy=mphy[[1]])
#'X = cbind(rep(1,150),x)
#'y = rbinTrait(n=1,phy=mphy[[1]], beta=c(-1,0.5), alpha=.7 ,X=X)
#'dat = data.frame(y, x)
#'# Run sensitivity analysis:
#'tree <- tree_phyglm(y ~ x, data = dat, phy = mphy, n.tree = 30)
#'# summary results:
#'summary(tree)
#'# Visual diagnostics for phylogenetic uncertainty:
#'sensi_plot(tree)
#' @export

tree_phyglm <- function(formula,data,phy,
                         n.tree=2,btol=50,track=TRUE,...){

  #Error check
  if(class(formula)!="formula") stop("formula must be class 'formula'")
  if(class(data)!="data.frame") stop("data must be class 'data.frame'")
  if(class(phy)!="multiPhylo") stop("phy must be class 'multiPhylo'")
  if(length(phy)<n.tree) stop("'n.tree' must be smaller (or equal) than the number of trees in the 'multiPhylo' object")
  else
    
    #Matching tree and phylogeny using utils.R
    datphy<-match_dataphy(formula,data,phy,...)
  full.data<-datphy[[1]]
  phy<-datphy[[2]]
  
  # If the class of tree is multiphylo pick n=n.tree random trees
  trees<-sample(length(phy),n.tree,replace=F)
  
  #Create the results data.frame
  sensi.estimates<-data.frame("n.tree"=numeric(),"intercept"=numeric(),"se.intercept"=numeric(),
                                   "pval.intercept"=numeric(),"estimate"=numeric(),"se.estimate"=numeric(),
                                   "pval.estimate"=numeric(),"aic"=numeric(),"optpar"=numeric())
  
  #Model calculation
  counter=1
  errors <- NULL
  c.data<-list()
  if(track==TRUE) pb <- utils::txtProgressBar(min = 0, max = n.tree, style = 3)
  for (j in trees){
    
    #Match data order to tip order
    full.data <- full.data[phy[[j]]$tip.label,]
    
    #phyloglm model
    mod = try(phylolm::phyloglm(formula, data=full.data,phy=phy[[j]],method="logistic_MPLE",btol=btol),FALSE)

    if(isTRUE(class(mod)=="try-error")) {
      error <- j
      names(error) <- rownames(c.data$full.data)[j]
      errors <- c(errors,error)
      next }
    
    
    else{
      intercept            <- phylolm::summary.phyloglm(mod)$coefficients[[1,1]]
      se.intercept         <- phylolm::summary.phyloglm(mod)$coefficients[[1,2]]
      estimate             <- phylolm::summary.phyloglm(mod)$coefficients[[2,1]]
      se.estimate          <- phylolm::summary.phyloglm(mod)$coefficients[[2,2]]
      pval.intercept       <- phylolm::summary.phyloglm(mod)$coefficients[[1,4]]
      pval.estimate        <- phylolm::summary.phyloglm(mod)$coefficients[[2,4]]
      aic.mod              <- mod$aic
      n                    <- mod$n
      #d                   <- mod$d
      optpar               <- mod$alpha

      if(track==TRUE) utils::setTxtProgressBar(pb, counter)
      
      #write in a table
      estim.simu <- data.frame(j, intercept, se.intercept, pval.intercept,
                               estimate, se.estimate, pval.estimate, aic.mod, optpar,
                               stringsAsFactors = F)
      sensi.estimates[counter, ]  <- estim.simu
      counter=counter+1
      
    }
  }
  if(track==TRUE) on.exit(close(pb))
  #calculate mean and sd for each parameter
  #variation due to tree choice
  statresults<-data.frame(min=apply(sensi.estimates,2,min),
                          max=apply(sensi.estimates,2,max),
                          mean=apply(sensi.estimates,2,mean),
                          sd_tree=apply(sensi.estimates,2,stats::sd))[-1, ]
  
  statresults$CI_low  <- statresults$mean - qt(0.975, df = n.tree-1) * statresults$sd_tree / sqrt(n.tree)
  statresults$CI_high <- statresults$mean + qt(0.975, df = n.tree-1) * statresults$sd_tree / sqrt(n.tree)
  
  res <- list(call = match.call(),
              formula=formula,
              data=full.data,
              sensi.estimates=sensi.estimates,N.obs=n,
              stats = round(statresults[c(1:6),c(3,5,6)],digits=3),
              all.stats = statresults)
  class(res) <- c("sensiTree","sensiTreeL")
  return(res)
}
