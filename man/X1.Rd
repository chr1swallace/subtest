% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/single_snps.R
\name{X1}
\alias{X1}
\title{X1}
\usage{
X1(Z, pars1)
}
\arguments{
\item{Z}{n x 2 matrix of Z scores; Z[,1]=Z_d, Z[,2]=Z_a}

\item{pars1}{parameters of full model; in order, pi0, pi1, tau, sigma_1, sigma_2, rho}
}
\value{
vector of values of X1
}
\description{
Compute test statistic X1, posterior probability of Za and Zd in full model.
}
\examples{
nn=100000
Z=abs(rbind(rmnorm(0.8*nn,varcov=diag(2)), rmnorm(0.15*nn,varcov=rbind(c(1,0),c(0,2^2))), rmnorm(0.05*nn,varcov=rbind(c(3^2,2),c(2,4^2)))));
pars=c(0.8,0.15,3,2,4,2)
X1=X1(Z,pars)
plotZ(Z,rlim=2); points(Z[which(X1>0.7),],col="red",pch=16)
}
\author{
James Liley
}

