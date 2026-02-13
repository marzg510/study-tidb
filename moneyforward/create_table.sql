CREATE TABLE `mf_transactions` (
  `is_calculation_target` tinyint(1) DEFAULT NULL,
  `tx_date` date DEFAULT NULL,
  `description` varchar(512) DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `institution` varchar(512) DEFAULT NULL,
  `category_major` varchar(512) DEFAULT NULL,
  `category_minor` varchar(512) DEFAULT NULL,
  `memo` text DEFAULT NULL,
  `is_transfer` bigint DEFAULT NULL,
  `id` varchar(512) NOT NULL,
  PRIMARY KEY (`id`)
)