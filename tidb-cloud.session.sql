SELECT
  cmj.order_no,
  tr.category_major,
  tr.category_minor,
  SUM(CASE WHEN YEAR(tx_date) = 2024 THEN -amount ELSE 0 END) AS '2024',
  SUM(CASE WHEN YEAR(tx_date) = 2025 THEN -amount ELSE 0 END) AS '2025',
  SUM(CASE WHEN YEAR(tx_date) = 2026 THEN -amount ELSE 0 END) AS '2026'
FROM mf_transactions tr
LEFT JOIN category_major cmj ON tr.category_major = cmj.category_major
WHERE is_calculation_target = 1
AND tr.category_major in ('食費', '現金・カード', '趣味・娯楽')
GROUP BY tr.category_major, category_minor
ORDER BY cmj.order_no, category_minor
;
