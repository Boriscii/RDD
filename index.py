import pandas as pd
import statistics as st

import warnings
import statsmodels.formula.api as smf



class RDD:
	def __init__(self, x, y, prior=False, metric='diff'):
		df = {
			'treatment': x,
			'outcome': y
		}


		if prior:
			self.prior = prior
			self.isPrior = True
		else:
			self.isPrior = False

		self.data = pd.DataFrame(df).sort_values(by='treatment')
		self.metric = metric


	def _isClose(self, estimate):
		condition = self.prior[0]
		prior = self.prior[1]

		if prior * (condition + 1) < estimate:
			return False
		elif prior / (condition + 1) > estimate:
			return False
		else:
			return True

	def _labelTreatment(self, metric='diff'):
		n_samples = len(self.data['treatment'])
		gap_index = 0
		criterion = 0
		
		for i in range(2, (n_samples - 2)):
			halfone = self.data['outcome'][:i]
			halftwo = self.data['outcome'][(i+1):]

			if metric == 'diff':
					_criterion = (st.mean(halfone) - st.mean(halftwo)) ** 2
			elif metric == 'var':
					_criterion = 1/(st.stdev(halfone) + st.stdev(halftwo))

			if _criterion > criterion:
				criterion = _criterion
				gap_index = i

		if gap_index < (n_samples * 0.9) and gap_index > (n_samples * 0.1):
			return gap_index
		else:
			return False

		
	def fit(self, usePrior = False):

		if usePrior:
			self.threshold = self.prior[1]
			return {
				'isSuccess': True,
				'threshold': self.threshold
			}

		gap_index = self._labelTreatment(self.metric)

		if not gap_index:
			if self.isPrior:
				threshold_estimate = self.prior[1]
			else:
				return {
					'isSuccess': False,
					'message': "The algorithm didn't converge. Try another metric."
				}
		else:
			threshold_estimate = self.data['treatment'][gap_index]

		if self.isPrior:
			if self._isClose(threshold_estimate):
				threshold = threshold_estimate
			else:
				threshold = self.prior[1]
				warnings.warn("Estimated threshold is not sufficently close to the prior. Reverting threshold estimate to the prior.")
		else:
			threshold = threshold_estimate

		self.data['treatment'] -= threshold
		self.threshold = threshold

		return {
			'isSuccess': True,
			'threshold': self.threshold
		}


	def estimate(self):

		if hasattr(self, 'threshold'):
			rdd_df = self.data.assign(threshold=(self.data["treatment"] > 0).astype(int))

			model = smf.wls("outcome~treatment*threshold", rdd_df).fit()

			pval = model.pvalues['threshold']
			return {
				'p_val': pval,
				'isSuccess': True
			}
		else:
			return {
				'isSuccess': False,
				'message': "Incomplete fitting stage"
			}
	
