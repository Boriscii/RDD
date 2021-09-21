
# RDD
This is a tool for automated threshold selection in RDD models (Thistlethwaite & Campbell, 1960). This class of models is robust for many learning evaluation purposes but I found it hard to explain the principle to a non-technical audience.
The exported object `RDD` uses brute-force to find most suitable threshold and run an automated RDD regression set-up. 
You may find the module useful if you need to provide an automated RDD setting "as a service": for example, I added pandas on top which allowed for a simple Excel integration helpful for multiple applications within training and service quality evaluation. 

## Deps

The script depends on the `statsmodels` module (can be installed with `pip3 install statsmodels`).

## Docs


*`(class) RDD (x, y, prior=False, metric='diff')`*

 - x : list, default = None, Treatment variable as a list of X values with no gaps
 - y: list, default = None, Outcome variable as a list of Y values with no gaps
 - prior: list or bool, default = False, Flag which tells if a prior threshold assumption should be used. If you'd like to have a prior, supply a list in the format *[error_margn,  prior_value]*. Express maximum allowed error margin on the (0,1) scale and prior value as a number in the original units of X.
 - metric : str, default = 'diff'. This is the criteria of threshold selection. It can be either 'diff' – maximise difference between treated and control groups or 'var' – minimise intragroup variance of the treated and control group. 

`(function) RDD.fit (usePrior = False)`
 - usePrior : bool, default = False, Enforces use of the prior and halts estimation if True
 
The function fits treatment group to find the best threshold. It has a complexity of O(N^2) so if you're dealing with N > 100 (+-) it's best to use and enforce a prior. **It is possible to optimise it but I advice not to try!** RDD is **really** dependent on choosing a good threshold and an approximation would inevitably sacrifice some accuracy which may render important effects to appear insignificant. 

**return: dict**

 -- isSuccess, bool – either True or False depending on the outcome of the fitting stage
 
 -- message, str - only in case of failure, explains reason.
 
-- threshold, float - only in case of success, fitted threshold value.
 
`(function) RDD.estimate ()`

**return: dict**

 -- isSuccess, bool – either True or False depending on the outcome of the fitting stage
 
 -- message, str - only in case of failure, explains reason.
 
 -- p_val, float -  only in case of success, p-value of the treatment effect significance.
 
 ## Test
 I have a small testing set in the folder `test` (extracted from Carpenter & Dobkin, 2009). 
 
 ## Reference
 Carpenter C, Dobkin C. The Effect of Alcohol Consumption on Mortality: Regression Discontinuity Evidence from the Minimum Drinking Age. Am Econ J Appl Econ. 2009 Jan 1;1(1):164-182. doi: 10.1257/app.1.1.164. PMID: 20351794; PMCID: PMC2846371.
 
  Thistlethwaite, D.; Campbell, D. (1960). "Regression-Discontinuity Analysis: An alternative to the ex post facto experiment". Journal of Educational Psychology. 51 (6): 309–317. doi:10.1037/h0044319.
