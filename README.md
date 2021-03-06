Subtest

A package for testing for differential genetic basis between two putative disease subtypes

An important consideration in genomic analysis is the question of whether disease heterogeneity arises from differences in genetic causality or differences in environment. Furthermore, accounting for genetically-driven disease heterogeneity can strengthen the ability to detect disease-causative variants. The question of whether putative subtypes of a disease phenotype have differential genetic basis can be addressed by analysis of appropriate SNP case-control data. This package implements a proposed method and generates supporting data.
 
We analyse disease heterogeneity as characterised either by a division of the case group into two subtypes or parametrised by a single quantitative variable. Our overall approach is to compute two Z-scores, one comparing cases with controls and the other characterising phenotypic heterogeneity without accounting for controls. We then look for SNPs which deviate from expectancy in both scores, under the assumption that if the difference in case subtypes corresponds to different causal genetic architecture, then SNPs which differentiate the case subtypes should also in general be associated with the overall phenotype. Because most SNPs will not be associated with the phenotype, and others may be associated with the phenotype without differentiating subtypes, we accomplish this by fitting a multivariate mixture Gaussian model under two hypotheses (null and full). The difference in fit of the two models, and hence the evidence for differential genetic basis of subtypes, is assessed by means of an adapted likelihood-ratio test.

Broadly, the package performs four main functions: generation of Z scores, fitting of models, assessment of models by simulation of random subtypes, and analysis of single SNPs. Input should be a SnpMatrix object (package SnpStats) which has been rigorously QC'd and either pruned to minimal linkage disequilibrium between SNPs or had weights calculated by the LDAK algorithm (http://dougspeed.com/ldak/). Output includes a p-value for the evidence of differential genetic basis in subgroups (under the null hypothesis of independence of causative basis of disease heterogeneity and disease causality) and information about the behaviour of random subgroups under the same test. Fitted values give some indication of the genetic architecture of the disease; namely the approximate proportions of null SNPs and SNPs which are disease-causative without differentiating subtypes, and the (multivariate) distribution of effect sizes of causative SNPs.

Further information can be found in the pending publication.

### Installation from within R
```
library(devtools)
install_github(jamesliley/subtest)
```

### Loading the library in R
```
library(Subtest)
```
