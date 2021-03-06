% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/simulations.R
\name{p_mixchi}
\alias{p_mixchi}
\title{p_mixchi}
\usage{
p_mixchi(x, S = NULL, gamma = NULL, kappa = NULL, p0 = NULL)
}
\arguments{
\item{x}{list of plr values at which to compute p value}

\item{S}{object of class sim_output; output from sim_analysis}

\item{gamma}{scaling factor for chi-squared. Overrides sim if set.}

\item{kappa}{mixing proportion of chi_1^2. Overrides sim if set}

\item{p0}{proportion of plr values which are negative. Overrides sim if set. If gamma and kappa are set, default is 0.}
}
\value{
list of p-values
}
\description{
Computes a p-value assuming the PLR follows a mixture chi-squared distribution.
}
\examples{
gamma=0.7; kappa=0.3; N=1000;
 n1=round(kappa*N); n2=N-n1; Xs=gamma*c(qchisq((1:n1)/(1+n1),df=1),qchisq((1:n2)/(1+n2),df=2))

 pp=p_mixchi(Xs,gamma=gamma,kappa=kappa)
 plot((1:length(pp))/(1+length(pp)),sort(pp),xlab="Quantile in U(0,1)",ylab="P-value"); abline(0,1,col="red")
p_mixchi(10,gamma,kappa)
}
\author{
James Liley
}

