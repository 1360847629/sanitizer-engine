-- init.sql
CREATE TABLE IF NOT EXISTS `job_request` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_content` longblob NOT NULL,
  `file_content_content_type` varchar(255) NOT NULL,
  `score` int DEFAULT NULL,
  `status` varchar(255) NOT NULL,
  `file_type` varchar(255) NOT NULL,
  `request_type` varchar(255) NOT NULL,
  `priority` varchar(255) NOT NULL,
  `file_name` varchar(255) DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;