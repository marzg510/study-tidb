select year(tx_date), month(tx_date)
, sum(CASE WHEN amount < 0 THEN -amount ELSE 0 END) as expense
, sum(CASE WHEN amount > 0 THEN amount ELSE 0 END) as income
, sum(amount) as balance
from mf_transactions
WHERE 0=0
AND is_calculation_target = 1
AND year(tx_date) = 2025
GROUP BY year(tx_date), month(tx_date)
ORDER BY year(tx_date), month(tx_date)
;
