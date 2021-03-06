# Simulate genotypes at a set of autosomal SNPs for a phenotype satisfying the assumptions of either H1 or H0.

##' Simulate a matrix of genotypes following a set of model parameters. Sets global variable pars_true containing 'true' parameter values, and or_true containing details of underlying odds ratio distribution.
##' 
##' @title sim_genotypes
##' @param n_snps number of SNPs
##' @param n_control number of controls
##' @param n_case two-element vector; number of cases in subtypes 1 and 2
##' @param pars expected observed parameter values. If NULL, values are chosen randomly; pi0 from c(0.1,0.01,0.001),1), pi1 from c(0.2,0.1,0.05); if parameter q2SEd is null, q2SEd from c(1,1.2,1.5,2); if parameter q2SEa is null, q2SEa1 from c(1.2,1.5,2); if parameter q2SEa is null and null_model==FALSE, q2SEa2 from c(1.2,1.5,2); if parameter rho is null and null_model==TRUE, rho from c(0, 0)
##' @param q2SEd 97.5% quantile (ie, +2SD) of population odds-ratios for subtype-differentiating SNPs. Corresponds to 'tau' in pars and overrides tau if set.
##' @param q2SEa1 97.5% quantile (ie, +2SD) of population odds-ratios for disease-causative SNPs which do NOT differentiate subtypes (group 2). Corresponds to sigma_1 and overrides sigma_1 if set.
##' @param q2SEa2 97.5% quantile (ie, +2SD) of population odds-ratios for disease-causative SNPs which DO differentiate subtypes (group 3). Corresponds to sigma_2 and overrides sigma_2 if set.
##' @param cor_st correlation, NOT covariance, between s2 and tau. Overrides pars if set.
##' @param seed random seed; if NULL is set to clock time
##' @param return_matrix if TRUE, returns a SNP matrix, otherwise returns Z_a and Z_d scores
##' @param null_model if pars=NULL and other parameters are null, parameters are chosen randomly. If null_model=TRUE, parameters are chosen from H0, otherwise H1.
##' @return either object of type SnpMatrix, in which indices are in order controls, case subtype 1, case subtype 2; or Z_d and Z_a scores in an n x 2 matrix (Z[,1]=Z_d, Z[,2]=Z_a). Global variable pars_true contains 'true' values of parameters of Z_a, Z_d distribution and can be used to start the fitting algorithm. Global variable or_true contains values (pi0,pi1,q2SEd,q2SEa1,q2SEa2,cor_st)
##' @export
sim_genotypes=function(n_snps=5e4,n_control=2000,n_case=c(1000,1000), pars=NULL,q2SEd=NULL,q2SEa1=NULL,q2SEa2=NULL,cor_st=NULL,seed=NULL,return_matrix=FALSE,null_model=TRUE) {

if (is.null(seed)) {
 options(digits.secs=6);
 seed=as.numeric(substr(Sys.time(),21,26))
}


if (!is.numeric(seed)) stop("Parameter seed must be an integer")
if (!is.numeric(n_case)) stop("Parameter n_case must be either a vector of two integers or a single integer")
if (!is.null(pars)) if (length(pars)!=6| !is(pars,"numeric")| max(pars[1:2])>1| pars[1]+pars[2]>1| min(pars[1:5])<= 0 | pars[6]==0 | pars[6]>pars[3]*pars[5])
  stop("Parameter pars must be a six-element vector containing elements (pi0,pi1,tau,sigma_1,sigma_2,rho). The first five elements must be strictly positive and the sixth nonnegative. Parameters pi0 and pi1 must be less than 1 and sum to less than 1. Parameter rho must be less than tau*sigma_2.")

# Set random seed
seed=round(seed)
set.seed(seed)


# Options for simulation. 
if (length(n_case)==1) n_case=c(round(n_case/2),n_case-round(n_case/2))
n_cases1=n_case[1];
n_cases2=n_case[2];

if (!is.null(pars)) {
pi0=pars[1]
pi1=pars[2]
pi2= 1-pars[1]-pars[2]

if (is.null(q2SEd)) q2SEd = exp(2*s2p(pars[3],n_case[1],n_case[2]))
if (is.null(q2SEa1)) q2SEa1 = exp(2*s2p(pars[4],n_case[1]+n_case[2],n_control))
if (is.null(q2SEa2)) q2SEa2 = exp(2*s2p(pars[5],n_case[1]+n_case[2],n_control))
if (is.null(cor_st)) cor_st=pars[6]/(pars[3]*pars[5])

} else { # choose values for simulation randomly

pi2=sample(c(0.1,0.02,0.01,0.002,0.001),1) # Randomly choose this
pi1= sample(c(0.2,0.1,0.05),1) # assume at least half of all SNPs are null
pi0=1-pi1-pi2
    
q2SEa1= sample(c(1.1,1.2,1.3,1.5,2),1) # 95% quantile for odds ratios between cases/controls for SNPs in group 2
q2SEd= sample(c(1.1,1.2,1.3,1.5,2),1) # Same for odds ratios between subtypes for SNPs in group 3

if (!null_model) {
  q2SEa2= sample(c(1.1,1.2,1.3,1.5,2),1)  ##### 95% quantile for odds ratios between cases/controls for SNPs in group 3 (only chosen if null_model=FALSE)
  cor_st=sample(c(0,0.1,0.5),1)
}

################
if (runif(1)>0.5) {
  q2SEa2= sample(c(1.1,1.2,1.3,1.5,2),1)
  q2SEd= sample(c(1.1,1.3),1) # sample(c(1.1,1.2,1.3,1.5,2),1)
} else {
  q2SEa2= sample(c(1.1,1.3),1) # sample(c(1.1,1.2,1.3,1.5,2),1)
  q2SEd= sample(c(1.1,1.2,1.3,1.5,2),1)
}
#############

  
}


n2=round(pi2*n_snps); n1=round(pi1*n_snps); n0=n_snps-n1-n2 # number of SNPs in each group

u_tau=log(q2SEd)/2 # Underlying standard deviation corresponding to tau
u_s1=log(q2SEa1)/2 # Underlying standard deviation corresponding to sigma_1
u_s2=log(q2SEa2)/2 # Underlying standard deviation corresponding to sigma_1
u_rho=cor_st*u_s2*u_tau

u_or0=cbind(rep(0,n0),rep(0,n0)) # Underlying odds ratios for SNPs in group 1 (all 0)
if (u_s1>0) u_or1=cbind(rep(0,n1),rnorm(n1,sd=u_s1)) else u_or1=cbind(rep(0,n1),rep(0,n1)) # Underlying odds ratios for SNPs in group 2
if (u_s2>0 & u_tau>0) u_or2=rmnorm(n2,varcov=rbind(c(u_tau^2,u_rho),c(u_rho,u_s2^2))) else {
  if (u_s2>0) p_s2=rnorm(n2,sd=u_s2) else p_s2=rep(0,n2) # Underlying odds ratios for SNPs in group 3
  if (u_tau>0) p_tau=rnorm(n2,sd=u_tau) else p_tau=rep(0,n2) # Underlying odds ratios for SNPs in group 3
  u_or2=cbind(p_tau,p_s2)
}
u_or=exp(rbind(u_or0,u_or1,u_or2)) # overall underlying odds ratios


umaf_population=runif(n_snps,0.01,0.5) # Population (underlying) minor allele frequencies in controls for all SNPs; assume >1%

cc=or_solve(umaf_population,u_or[,2],n_control,n_case[1]+n_case[2])
umaf_control=cc[,1]
umaf_case=cc[,2]
cc2=or_solve(umaf_case,u_or[,1],n_case[1],n_case[2])
umaf_case1=cc2[,1]
umaf_case2=cc2[,2]

gen_control= mapply(function(x) sample(0:2,n_control,replace=TRUE,prob=c((1-x)^2,2*x*(1-x),x^2)),umaf_control) # Simulated genotypes for controls
gen_case1= mapply(function(x) sample(0:2,n_case[1],replace=TRUE,prob=c((1-x)^2,2*x*(1-x),x^2)),umaf_case1) # Simulated genotypes for controls
gen_case2= mapply(function(x) sample(0:2,n_case[2],replace=TRUE,prob=c((1-x)^2,2*x*(1-x),x^2)),umaf_case2) # Simulated genotypes for controls

if (!is.null(pars)) pars_true <<- pars else {
  if (!null_model) {
    s2x=p2s(u_s2,n_control,n_case[1]+n_case[2])
    taux=p2s(u_tau,n_case[1],n_case[2])
    pars_true <<- c(pi0,pi1,taux,p2s(u_s1,n_control,n_case[1]+n_case[2]),s2x,u_rho*s2x*taux) 
  } else {
    pars_true <<- c(pi0,pi1,p2s(u_tau,n_case[1],n_case[2]),p2s(u_s1,n_control,n_case[1]+n_case[2]),1,0)    
  } 
}

or_true <<- c(pi0,pi1,q2SEd,q2SEa1,q2SEa2,cor_st)
names(or_true)=c("pi0","pi1","q2SEd","q2SEa1","q2SEa2","cor")

if (return_matrix) return(as(rbind(gen_control,gen_case1,gen_case2),"SnpMatrix")) else {
#MA=as(rbind(gen_control,gen_case1,gen_case2),"SnpMatrix")
#MD=as(rbind(gen_case1,gen_case2),"SnpMatrix")
#pa=p.value(single.snp.tests(c(rep(1,n_control),rep(2,n_case[1]+n_case[2])),snp.data=MA),df=1)
#pd=p.value(single.snp.tests(c(rep(1,n_case[1]),rep(2,n_case[2])),snp.data=MD),df=1)
#return(-qnorm(cbind(pd/2,pa/2)))

mct=colSums(gen_control); mc1=colSums(gen_case1); mc2=colSums(gen_case2); mcs=mc1+mc2; ncs=n_case[1]+n_case[2]

xxa=cbind(mct,(2*n_control)-mct,mcs,(2*ncs)-mcs); ppa=(mct+mcs)/(2*(n_control+ncs)); eea=cbind(2*n_control*ppa,2*n_control*(1-ppa),2*ncs*ppa,2*ncs*(1-ppa))
za=-qnorm((pchisq(rowSums(((xxa-eea)^2)/eea),df=1,lower.tail=FALSE))/2) # z score from chi squared test

xxd=cbind(mc1,(2*n_case[1])-mc1,mc2,(2*n_case[2])-mc2); ppd=(mc1+mc2)/(2*(ncs)); eed=cbind(2*n_case[1]*ppd,2*n_case[2]*(1-ppd),2*n_case[2]*ppd,2*n_case[2]*(1-ppd))
zd=-qnorm((pchisq(rowSums(((xxd-eed)^2)/eed),df=1,lower.tail=FALSE))/2) # z score from chi squared test

return(cbind(zd,za))
}

}




##' Converts underlying 'population' odds-ratio distribution into corresponding expected value of SD(Z) (ie, tau, sigma_1, or sigma_2). Assume that, across some set of SNPs in, population log-odds ratios between two phenotypes A and B are normally distributed with standard deviation p. If a GWAS is performed between a group of samples with phenotype A of size n1 and a group of samples of phenotype B of size n2, and Z-scores calculated for each SNP, this function returns the corresponding standard deviation for these Z scores.
##' 
##' @title p2s
##' @param p standard deviation of underlying log odds ratio distribution
##' @param n1 number of samples in group 1
##' @param n2 number of samples in group 2
##' @param mafs use to specify distribution of average MAF (across both groups). Default is MAF~U(0.01,0.5)
##' @param NS number of SNPs to use in simulation
##' @return expected value of observed standard deviation of Z scores.
p2s=function(p,n1,n2,mafs=NULL,NS=50000) {
  
  if (!is.null(mafs) & !is.numeric(mafs)) stop ("Parameter mafs must be a list of minor allele frequencies")
  
  if (is.null(mafs)) {
    mafs=runif(NS,0.01,0.5) # mean MAFs 
  } else NS=length(mafs)  # number of SNPs
  if (p==0) return (1) else {
  or=exp(rnorm(NS,sd=p)) # odds ratios
  
  cc=or_solve(mafs,or,n1,n2); c1=cc[,1]; c2=cc[,2]
  
  g1=rnorm(NS,mean=c1,sd=sqrt(c1*(1-c1)/(2*n1))); g2=rnorm(NS,mean=c2,sd=sqrt(c2*(1-c2)/(2*n2))) # observed minor allele frequencies, assuming normal approximation to binomial
  w=which(g1>0.01 & g2>0.01); g1=round(2*n1*g1[w]); g2=round(2*n2*g2[w])
                                                             
  xx=cbind(g1,(2*n1)-g1,g2,(2*n2)-g2); pp=(g1+g2)/(2*(n1+n2)); ee=cbind(2*n1*pp,2*n1*(1-pp),2*n2*pp,2*n2*(1-pp))
  stat=-qnorm((pchisq(rowSums(((xx-ee)^2)/ee),df=1,lower.tail=FALSE))/2) # z score from chi squared test
  stat=stat[which(stat!=Inf)]
  return(sqrt(mean(stat^2)))
}      
}





##' Inverse function for p2s. Converts expected values of SD(Z) (ie, tau, sigma_1, or sigma_2) into underlying 'population' odds-ratio distribution. Assume that, across some set of SNPs in, population log-odds ratios between two phenotypes A and B are normally distributed with standard deviation p. If a GWAS is performed between a group of samples with phenotype A of size n1 and a group of samples of phenotype B of size n2, and Z-scores calculated for each SNP with standard deviation s, this function recovers p.
##' 
##' @title s2p
##' @param s standard deviation of underlying log odds ratio distribution
##' @param n1 number of samples in group 1
##' @param n2 number of samples in group 2
##' @param mafs use to specify distribution of average MAF (across both groups). Default is MAF~U(0.01,0.5)
##' @param NS number of SNPs to use in simulation
##' @return expected value of observed standard deviation of Z scores.
s2p=function(s,n1,n2,mafs=NULL,NS=50000) {
  
  if (!is.null(mafs) & !is.numeric(mafs)) stop ("Parameter mafs must be a list of minor allele frequencies")
  
  if (is.null(mafs)) {
    mafs=runif(NS,0.01,0.5) # mean MAFs 
  } else NS=length(mafs)  # number of SNPs
  if (s==1) return (0) else {
  
  ff=function(x) p2s(x,n1,n2,mafs,NS)-s
  
  return(uniroot(ff,c(0,1))$root)
  }
}



##' Given a list of 'population' minor allele frequencies 'mafs' and population odds ratios 'ors', for two groups of size n1, n2 generates lists of MAFs m1, m2 such that
##' OR(m1,m2)=m1(1-m2)/(m2(1-m1))=ors
##' (m1 n1 + m2 n2)/(n1+n2) = mafs
##' 
##' @title or_solve
##' @param mafs list of 'population' minor allele frequencies
##' @param ors list of 'population' odds ratios
##' @param n1 size of group 1
##' @param n2 size of group 2
##' @return n x 2 array where n=length(mafs); n[,1] is MAFs in group 1, n[,2] MAFS in group 2.
##' @examples
##' N=5000
##' mafs=runif(N,0.01,0.5); ors=exp(rnorm(N,sd=0.2)); n1=1000;n2=2000
##' mm=or_solve(mafs,ors,n1,n2)
##' plot((n1*mm[,1] + n2*mm[,2])/(n1+n2),mafs)
##' plot(mm[,1]*(1-mm[,2])/(mm[,2]*(1-mm[,1])),ors)
or_solve=function(mafs,ors,n1=1000,n2=1000) {
  out=cbind(mafs,mafs)
  x=mafs*(n1+n2); y=ors; D=sqrt(abs((4*n2*x*(y-1))+((n2 + x + (n1*y) - (x*y))^2)))
  out[which(y!=1),]=cbind((n2 - x + (n1*y) + (x*y) - D)/(2*n1*(y-1)),(-n2 - x - (n1*y) + (x*y) + D)/(2*n2*(y-1)))[which(y!=1),]
  out
}
