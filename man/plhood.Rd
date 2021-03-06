% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/fit.mml5.R
\name{plhood}
\alias{plhood}
\title{Pseudo-likelihood for a set of observations of Z_d and Z_a}
\usage{
plhood(Z, pars, weights = rep(1, dim(Z)[1]), sumlog = TRUE, C = 1)
}
\arguments{
\item{Z}{an n x 2 array; Z[i,1], Z[i,2] are the Z_d and Z_a scores respectively for the ith SNP}

\item{pars}{vector containing initial values of pi0,pi1,tau,sigma1,sigma2,rho.}

\item{weights}{SNP weights to adjust for LD; output from LDAK procedure}

\item{sumlog}{set to TRUE to return the (weighted) sum of log pseudo-likelihoods for each datapoint; FALSE to return a vector of pseudo-likelihoods for each datapoint.}

\item{C}{scaling factor for adjustment}
}
\value{
value of pseudo- log likelihood of all observations (if sumlog==TRUE) or vector of n pseudo-likelihoods (if sumlog==FALSE)
}
\description{
Pseudo-likelihood for a set of observations of Z_d and Z_a
}
\author{
James Liley
}

