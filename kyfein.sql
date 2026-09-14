/*
SQLyog Community v13.1.7 (64 bit)
MySQL - 8.0.30 : Database - db_kyfein
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
CREATE DATABASE /*!32312 IF NOT EXISTS*/`db_kyfein` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `db_kyfein`;

/*Table structure for table `absensi` */

DROP TABLE IF EXISTS `absensi`;

CREATE TABLE `absensi` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `jadwal_shift_id` char(36) NOT NULL,
  `jam_masuk` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `jam_pulang` datetime DEFAULT NULL,
  `lat_masuk` decimal(11,8) NOT NULL,
  `lng_masuk` decimal(11,8) NOT NULL,
  `lat_pulang` decimal(11,8) DEFAULT NULL,
  `lng_pulang` decimal(11,8) DEFAULT NULL,
  `foto_masuk` text NOT NULL,
  `foto_pulang` text,
  `menit_telat` int NOT NULL DEFAULT '0',
  `izin_telat_id` char(36) DEFAULT NULL,
  `status_pulang` enum('tepat_waktu','telat','lupa_absen') DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_absensi_shift` (`jadwal_shift_id`),
  KEY `idx_absensi_jam_masuk` (`jam_masuk`),
  KEY `idx_absensi_karyawan` (`karyawan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `absensi` */

insert  into `absensi`(`id`,`karyawan_id`,`jadwal_shift_id`,`jam_masuk`,`jam_pulang`,`lat_masuk`,`lng_masuk`,`lat_pulang`,`lng_pulang`,`foto_masuk`,`foto_pulang`,`menit_telat`,`izin_telat_id`,`status_pulang`,`created_at`) values 
('1b5e5da3-d5b4-45e5-a49e-5ac3b7d7c12d','603660d6-d7c3-4c59-85c5-e5b1bc46fe90','62a7cf78-e470-415f-87da-d6d366e96a91','2026-09-14 09:31:56','2026-09-14 13:31:56',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 06:31:56'),
('1cae7e69-5e35-4ae5-a8a9-d56c1fa65744','12bb1290-c356-4533-91c4-b0203f86973b','f4d68374-048d-4232-9bb1-cc5dd8c215a3','2026-09-14 08:24:40','2026-09-14 12:24:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:24:40'),
('243385d2-5709-4a03-8514-fa33050ee020','97ce8977-104f-4e58-ab62-9f8e58090016','7d4124d8-2ee0-44c8-b3cf-0d363f97938f','2026-09-14 08:26:21','2026-09-14 12:26:21',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:26:21'),
('24877031-75aa-4740-82b9-ebae69bd024e','fddd2357-e42f-41c6-b5f8-18c5fff47b22','30f8b096-ff4f-4cac-87c8-f8f552776902','2026-09-14 08:25:37','2026-09-14 12:25:37',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:25:37'),
('2f302c2a-d2b2-4c21-895d-2a3639d037fa','e9960509-07ce-4e91-a9c5-54f90687cd4f','0e59d1d7-483f-41b0-9b08-81c71a77f5b7','2026-09-14 09:31:56','2026-09-14 13:31:56',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 06:31:56'),
('2f575ca1-41bd-4e25-83bc-416072cbf022','ca70f843-eadd-4252-9b40-39bc12d334b1','99f5b9d4-9f6c-4593-a99f-c5edc2abe443','2026-09-14 08:24:41','2026-09-14 12:24:41',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:24:41'),
('351c74cd-a3ae-4fde-a5e4-cab4bc04b088','ba60f984-b76b-422f-9f2e-e33dbd102818','d3f8fd45-fa5f-4ae8-b78f-224267f59875','2026-09-14 08:26:40','2026-09-14 12:26:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:26:40'),
('35f2c5fa-287a-4c52-8b80-7909c0c750fc','57e1c301-39d5-419b-acbc-4a586aeb5b89','3e054b52-17e8-4fe1-a2ac-dc1b7614048c','2026-09-14 10:26:20','2026-09-14 12:26:20',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:26:20'),
('43caab77-802a-419b-8dc5-70bdc5a994cf','c2fe3285-9f69-455e-ac7e-765ef0c9ed83','bef3d805-7f1a-4f2e-a39c-5de6fdc8376a','2026-09-14 08:26:40','2026-09-14 12:26:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:26:40'),
('4541d4e1-a74e-4035-b434-d74db2e55534','670b5760-1eaf-4590-8faf-60097352172c','0eb29e3e-57c2-4888-846b-02cd7753b4fb','2026-09-14 08:25:07','2026-09-14 12:25:07',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:25:07'),
('478aa177-eadd-4dc5-9de0-01026abf74ee','1b2e3e7c-2118-42a8-ace8-92c27bde427f','9549d367-eb52-47bc-b94b-e55ca4adf32a','2026-09-14 08:26:21','2026-09-14 12:26:21',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:26:21'),
('67ce5856-8e78-453a-a39c-b9a486eb57fc','ebc40f6a-49df-4610-9772-9da5ab3b82fb','5db94f86-30f9-4842-a6c9-095556a3da0e','2026-09-14 08:25:07','2026-09-14 12:25:07',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:25:07'),
('78489890-e597-4ef8-9d1a-9900feff05d9','628c8069-3cc2-4cf9-a308-37983e169b91','00b6b8ec-9242-4719-8bce-7cbd4fec6868','2026-09-14 11:31:56','2026-09-14 13:31:56',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 06:31:56'),
('861429ea-a22e-4ae5-83c0-e0b26761b477','dd74e1d9-2681-4671-9412-9e136d043b04','58658575-6ec7-47cf-b28b-8d104063a969','2026-09-14 09:31:29','2026-09-14 13:31:29',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 06:31:29'),
('89819b5a-14d7-41b9-923b-716c57c0e7d4','fdd199fa-30fc-4293-b800-cfb71f109d99','046fce22-c706-47cd-9d29-8386a9d42c91','2026-09-14 08:37:40','2026-09-14 12:37:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:37:40'),
('9a7f25b1-70bf-4adf-be7f-5e4382f46b31','e9d2999c-3476-4206-a9a2-9dfa290fed52','86a17169-85b1-4d5a-9f52-dd7bff6b4023','2026-09-14 09:31:28','2026-09-14 13:31:28',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 06:31:28'),
('a1fae4e9-85a4-48a8-b7cf-7bea17d94809','9e786dc3-c19c-4a64-bc83-bedd9bb22352','db786e17-b0ca-487f-a3a2-0e5d2cf163ff','2026-09-14 08:25:37','2026-09-14 12:25:37',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:25:37'),
('b34d7704-6870-434b-8d54-ff164d0e7b0a','f9f7546f-f81d-4a9c-8ea8-81f98ed86d7a','a05b312d-beca-4569-9395-cb294da50c09','2026-09-14 10:26:40','2026-09-14 12:26:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:26:40'),
('b9aecc46-805a-49fa-a1f0-267915168f37','929f0318-7211-4a32-8811-c3a462c73ee4','38fc0ccf-db35-46cf-bffc-e9bfb6620b13','2026-09-14 11:31:28','2026-09-14 13:31:28',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 06:31:28'),
('cb0e647f-59d9-4a9e-96ae-24f757b7bf8d','e000d455-02f2-4ea4-96e6-5fcb3e6c49ef','a38c6a99-33b8-4f05-87f8-84d7ac5057b3','2026-09-14 10:24:40','2026-09-14 12:24:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:24:40'),
('cb47029f-38b2-421a-b6d3-5537d1dc1a4d','8bbae7e9-3846-4c9c-91d2-5568abeaefa1','5dd7817b-ec33-4d1f-bcf2-eeabbbd16f8a','2026-09-14 10:25:37','2026-09-14 12:25:37',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:25:37'),
('d96174d3-348a-4630-ad70-632b75bb4900','8e63b64c-1530-4017-ad80-25fe07da02c4','597ec66f-c66d-45fc-89d4-9115786c4afa','2026-09-14 10:37:40','2026-09-14 12:37:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:37:40'),
('ec9db9c9-2d47-4a4c-8c57-2ef66e8ad8d3','6af10581-93b7-468a-9fdd-8b073fd9d9c9','d7849014-e164-47e7-af17-07250c5fb17e','2026-09-14 08:37:40','2026-09-14 12:37:40',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'telat','2026-09-14 05:37:40'),
('ede84514-75ba-49a9-8ae7-293910363223','0caed65f-5926-401b-9d55-e1ded7b15837','5cefce05-801b-4167-865f-c597cb50b348','2026-09-14 10:25:07','2026-09-14 12:25:07',-6.20000000,106.80000000,-6.20000000,106.80000000,'http://example.com/foto_masuk.jpg',NULL,0,NULL,'tepat_waktu','2026-09-14 05:25:07');

/*Table structure for table `audit_log_konfigurasi` */

DROP TABLE IF EXISTS `audit_log_konfigurasi`;

CREATE TABLE `audit_log_konfigurasi` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `tabel` varchar(50) NOT NULL,
  `row_id` char(36) NOT NULL,
  `data_lama` json DEFAULT NULL,
  `data_baru` json DEFAULT NULL,
  `diubah_oleh` char(36) DEFAULT NULL,
  `diubah_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `audit_log_konfigurasi` */

/*Table structure for table `bahan` */

DROP TABLE IF EXISTS `bahan`;

CREATE TABLE `bahan` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `nama` varchar(100) NOT NULL,
  `satuan` varchar(20) NOT NULL,
  `isi_per_kemasan` decimal(10,3) DEFAULT NULL,
  `stok_minimum` decimal(10,3) NOT NULL DEFAULT '0.000',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `harga_rata_rata` decimal(14,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id`),
  CONSTRAINT `bahan_chk_1` CHECK ((`harga_rata_rata` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `bahan` */

insert  into `bahan`(`id`,`nama`,`satuan`,`isi_per_kemasan`,`stok_minimum`,`created_at`,`updated_at`,`harga_rata_rata`) values 
('dad439fd-c5e3-41d0-9be0-23027c9cd93f','Test Kopi Espresso V4','gram',1000.000,500.000,'2026-09-14 01:40:31','2026-09-14 01:53:58',120.00);

/*Table structure for table `barang_keluar` */

DROP TABLE IF EXISTS `barang_keluar`;

CREATE TABLE `barang_keluar` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `titik_tujuan` enum('bar','kitchen') NOT NULL,
  `karyawan_id` char(36) NOT NULL,
  `waktu` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_barang_keluar_karyawan` (`karyawan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `barang_keluar` */

/*Table structure for table `barang_keluar_detail` */

DROP TABLE IF EXISTS `barang_keluar_detail`;

CREATE TABLE `barang_keluar_detail` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `barang_keluar_id` char(36) NOT NULL,
  `bahan_id` char(36) NOT NULL,
  `jumlah` decimal(10,3) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_barang_keluar_detail_keluar` (`barang_keluar_id`),
  KEY `idx_barang_keluar_detail_bahan` (`bahan_id`),
  CONSTRAINT `barang_keluar_detail_ibfk_1` FOREIGN KEY (`barang_keluar_id`) REFERENCES `barang_keluar` (`id`) ON DELETE CASCADE,
  CONSTRAINT `barang_keluar_detail_chk_1` CHECK ((`jumlah` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `barang_keluar_detail` */

/*Table structure for table `barang_masuk` */

DROP TABLE IF EXISTS `barang_masuk`;

CREATE TABLE `barang_masuk` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `keterangan` text,
  `waktu` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_barang_masuk_karyawan` (`karyawan_id`),
  KEY `idx_barang_masuk_waktu` (`waktu`),
  CONSTRAINT `fk_barang_masuk_karyawan` FOREIGN KEY (`karyawan_id`) REFERENCES `karyawan` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `barang_masuk` */

insert  into `barang_masuk`(`id`,`karyawan_id`,`keterangan`,`waktu`,`created_at`) values 
('26224278-1929-4778-93c4-335348f39c85','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:51:55','2026-09-14 01:51:55'),
('33057900-408d-4d60-bdea-54e9969d3ddb','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:49:20','2026-09-14 01:49:20'),
('3d9ac3e0-afdb-4e18-91dd-3682c41cfe95','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:41:03','2026-09-14 01:41:03'),
('40486948-1463-419e-99b9-47224b9a91e6','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:40:50','2026-09-14 01:40:50'),
('41277ac5-8a66-4158-975b-860fc29505f6','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:53:58','2026-09-14 01:53:58'),
('5e2ad574-9966-46d0-b1aa-a7c6c35250c1','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:51:55','2026-09-14 01:51:55'),
('785e8c51-0c40-4556-9adc-be7516bc50b4','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:50:13','2026-09-14 01:50:13'),
('7d84e819-a187-4b56-9fb2-617ac1a65f59','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:53:58','2026-09-14 01:53:58'),
('84c6e7dd-36b6-446b-ad69-597b7bd6ab73','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:50:26','2026-09-14 01:50:26'),
('84fa018e-7c00-4cda-928c-f6c8539c6863','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:50:13','2026-09-14 01:50:13'),
('9e987672-b1dd-42d6-b7d0-750045580c95','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:41:03','2026-09-14 01:41:03'),
('b0ab6610-be4d-4656-8258-b59e8f14cadb','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 2','2026-09-14 01:40:50','2026-09-14 01:40:50'),
('b0b456bf-699e-44b0-9f01-f0c1bb86e6c6','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:50:26','2026-09-14 01:50:26'),
('bd1c94f6-a05e-444d-a40b-8a3dac089134','aedbe233-819d-4023-97b5-7fb8610e4f28','Batch 1','2026-09-14 01:49:20','2026-09-14 01:49:20');

/*Table structure for table `barang_masuk_detail` */

DROP TABLE IF EXISTS `barang_masuk_detail`;

CREATE TABLE `barang_masuk_detail` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `barang_masuk_id` char(36) NOT NULL,
  `bahan_id` char(36) NOT NULL,
  `jumlah_kemasan_besar` int NOT NULL DEFAULT '0',
  `jumlah_satuan_kecil` decimal(10,3) NOT NULL DEFAULT '0.000',
  `harga_total` decimal(14,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_bmd_barang_masuk` (`barang_masuk_id`),
  KEY `fk_bmd_bahan` (`bahan_id`),
  CONSTRAINT `fk_bmd_bahan` FOREIGN KEY (`bahan_id`) REFERENCES `bahan` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_bmd_barang_masuk` FOREIGN KEY (`barang_masuk_id`) REFERENCES `barang_masuk` (`id`) ON DELETE CASCADE,
  CONSTRAINT `barang_masuk_detail_chk_1` CHECK ((`jumlah_kemasan_besar` >= 0)),
  CONSTRAINT `barang_masuk_detail_chk_2` CHECK ((`jumlah_satuan_kecil` >= 0)),
  CONSTRAINT `barang_masuk_detail_chk_3` CHECK ((`harga_total` > 0)),
  CONSTRAINT `chk_bmd_jumlah_masuk` CHECK (((`jumlah_kemasan_besar` > 0) or (`jumlah_satuan_kecil` > 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `barang_masuk_detail` */

insert  into `barang_masuk_detail`(`id`,`barang_masuk_id`,`bahan_id`,`jumlah_kemasan_besar`,`jumlah_satuan_kecil`,`harga_total`) values 
('034b47d5-ed86-45e6-8e3c-10b42974b43d','84c6e7dd-36b6-446b-ad69-597b7bd6ab73','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('197721eb-1826-4173-ba3d-16991ba62168','b0b456bf-699e-44b0-9f01-f0c1bb86e6c6','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('344c29f9-9d80-4618-821e-9f70294d8b3f','41277ac5-8a66-4158-975b-860fc29505f6','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('5ba8c522-1f04-4fe6-be91-df33265e7b32','40486948-1463-419e-99b9-47224b9a91e6','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('5d78f996-7dd0-4a54-8f5e-882a6eeec2b5','84fa018e-7c00-4cda-928c-f6c8539c6863','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('68a3bf3b-dc95-47c8-893d-3646b76f22da','5e2ad574-9966-46d0-b1aa-a7c6c35250c1','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('aa102d8d-7864-4f61-a534-49b6a6411020','b0ab6610-be4d-4656-8258-b59e8f14cadb','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('aa2e41ef-ae1a-46e3-9f22-2981eb5a32df','bd1c94f6-a05e-444d-a40b-8a3dac089134','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('aee0751b-2a0c-4c36-8535-9e262579b906','785e8c51-0c40-4556-9adc-be7516bc50b4','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('b3951b14-9823-4955-a324-480ac797fec6','26224278-1929-4778-93c4-335348f39c85','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('e222ad26-ab44-43fc-be98-4087441a0ee7','3d9ac3e0-afdb-4e18-91dd-3682c41cfe95','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('facf3113-b35c-49bf-b9a5-4e269d42ae37','33057900-408d-4d60-bdea-54e9969d3ddb','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00),
('faee39dd-5c60-488a-bb1d-4a066a6d65e7','7d84e819-a187-4b56-9fb2-617ac1a65f59','dad439fd-c5e3-41d0-9be0-23027c9cd93f',2,0.000,200000.00),
('fe1b392d-3c47-4631-a200-656f7b4b5009','9e987672-b1dd-42d6-b7d0-750045580c95','dad439fd-c5e3-41d0-9be0-23027c9cd93f',1,0.000,160000.00);

/*Table structure for table `izin_telat` */

DROP TABLE IF EXISTS `izin_telat`;

CREATE TABLE `izin_telat` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `jadwal_shift_id` char(36) NOT NULL,
  `alasan` text NOT NULL,
  `foto_url` text,
  `status` enum('pending','disetujui','ditolak') NOT NULL DEFAULT 'pending',
  `diajukan_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `diproses_oleh` char(36) DEFAULT NULL,
  `diproses_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_izin_telat_karyawan` (`karyawan_id`),
  KEY `idx_izin_telat_jadwal_shift` (`jadwal_shift_id`),
  KEY `idx_izin_telat_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `izin_telat` */

/*Table structure for table `izin_tidak_masuk` */

DROP TABLE IF EXISTS `izin_tidak_masuk`;

CREATE TABLE `izin_tidak_masuk` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `jadwal_shift_id` char(36) NOT NULL,
  `alasan` text NOT NULL,
  `foto_url` text NOT NULL,
  `status` enum('pending','disetujui','ditolak') NOT NULL DEFAULT 'pending',
  `diajukan_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `diproses_oleh` char(36) DEFAULT NULL,
  `diproses_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_izin_tidak_masuk_karyawan` (`karyawan_id`),
  KEY `idx_izin_tidak_masuk_jadwal_shift` (`jadwal_shift_id`),
  KEY `idx_izin_tidak_masuk_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `izin_tidak_masuk` */

/*Table structure for table `jadwal_shift` */

DROP TABLE IF EXISTS `jadwal_shift`;

CREATE TABLE `jadwal_shift` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `tanggal` date NOT NULL,
  `shift` enum('shift_1','shift_2') NOT NULL,
  `area_kerja` enum('kasir','bar','kitchen') NOT NULL DEFAULT 'kasir',
  `shift_template_id` char(36) DEFAULT NULL,
  `jam_mulai` time NOT NULL,
  `jam_selesai` time NOT NULL,
  `dibuat_oleh` char(36) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_karyawan_tanggal` (`karyawan_id`,`tanggal`),
  KEY `idx_jadwal_shift_tanggal` (`tanggal`),
  KEY `idx_jadwal_shift_karyawan` (`karyawan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `jadwal_shift` */

insert  into `jadwal_shift`(`id`,`karyawan_id`,`tanggal`,`shift`,`area_kerja`,`shift_template_id`,`jam_mulai`,`jam_selesai`,`dibuat_oleh`,`created_at`,`updated_at`) values 
('00b6b8ec-9242-4719-8bce-7cbd4fec6868','628c8069-3cc2-4cf9-a308-37983e169b91','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('046fce22-c706-47cd-9d29-8386a9d42c91','fdd199fa-30fc-4293-b800-cfb71f109d99','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:32:40',NULL,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('05f55aaf-6c07-46ff-b20c-b2707f5fe6e9','bf5e2bfe-7213-4529-a922-c8fb1c2a0585','2026-09-13','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 06:31:57','2026-09-14 06:31:57'),
('0e59d1d7-483f-41b0-9b08-81c71a77f5b7','e9960509-07ce-4e91-a9c5-54f90687cd4f','2026-09-14','shift_1','kasir',NULL,'06:00:00','13:26:56',NULL,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('0eb29e3e-57c2-4888-846b-02cd7753b4fb','670b5760-1eaf-4590-8faf-60097352172c','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:05:07',NULL,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('17355860-fb84-4a45-9d85-63f8c840acd4','7d1c9b27-108c-4700-b06b-2c42961e9518','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('30f8b096-ff4f-4cac-87c8-f8f552776902','fddd2357-e42f-41c6-b5f8-18c5fff47b22','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:05:37',NULL,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('38fc0ccf-db35-46cf-bffc-e9bfb6620b13','929f0318-7211-4a32-8811-c3a462c73ee4','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 06:31:28','2026-09-14 06:31:28'),
('399b5e5b-f09e-45ff-9b43-0dd43c6c9a74','72787fed-181f-4b1e-a9e8-1aab510d8aff','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:25:08','2026-09-14 05:25:08'),
('3e054b52-17e8-4fe1-a2ac-dc1b7614048c','57e1c301-39d5-419b-acbc-4a586aeb5b89','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:26:20','2026-09-14 05:26:20'),
('43605f91-cd2f-4c37-b032-af92d04dba3a','bb5206e1-ca56-47f2-8458-4964000c9a43','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:24:41','2026-09-14 05:24:41'),
('48aeb7c3-24c8-43f4-b173-bade53dec540','f81e4578-d711-4d85-87ad-756f24250722','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 06:31:29','2026-09-14 06:31:29'),
('4cd39a3e-51ee-4193-86ee-d7b03714d59d','54ac7aa7-43e6-46d2-8c41-5c7e8a9f500d','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:24:08','2026-09-14 05:24:08'),
('4e919c38-bc51-4db5-b7ca-650ca239bda6','6c0a94f5-0f4a-46a3-a320-a5202cff9fa3','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('58658575-6ec7-47cf-b28b-8d104063a969','dd74e1d9-2681-4671-9412-9e136d043b04','2026-09-14','shift_1','kasir',NULL,'06:00:00','13:26:29',NULL,'2026-09-14 06:31:29','2026-09-14 06:31:29'),
('597ec66f-c66d-45fc-89d4-9115786c4afa','8e63b64c-1530-4017-ad80-25fe07da02c4','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('5cefce05-801b-4167-865f-c597cb50b348','0caed65f-5926-401b-9d55-e1ded7b15837','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('5db94f86-30f9-4842-a6c9-095556a3da0e','ebc40f6a-49df-4610-9772-9da5ab3b82fb','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:20:07',NULL,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('5dd7817b-ec33-4d1f-bcf2-eeabbbd16f8a','8bbae7e9-3846-4c9c-91d2-5568abeaefa1','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('62a7cf78-e470-415f-87da-d6d366e96a91','603660d6-d7c3-4c59-85c5-e5b1bc46fe90','2026-09-14','shift_1','kasir',NULL,'06:00:00','13:11:56',NULL,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('7d4124d8-2ee0-44c8-b3cf-0d363f97938f','97ce8977-104f-4e58-ab62-9f8e58090016','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:06:21',NULL,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('7e74e8b6-e587-4ef7-ba42-5234d56c02d3','6a314e55-bd26-4ae5-aa0c-e71821968485','2026-09-14','shift_1','bar',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 06:31:57','2026-09-14 06:31:57'),
('86a17169-85b1-4d5a-9f52-dd7bff6b4023','e9d2999c-3476-4206-a9a2-9dfa290fed52','2026-09-14','shift_1','kasir',NULL,'06:00:00','13:11:28',NULL,'2026-09-14 06:31:28','2026-09-14 06:31:28'),
('94e9e004-ff3a-422f-8a4b-a8293222b031','a0eb13e2-7bef-4c75-aa2d-19c6b71c8bb3','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('9549d367-eb52-47bc-b94b-e55ca4adf32a','1b2e3e7c-2118-42a8-ace8-92c27bde427f','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:21:21',NULL,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('99f5b9d4-9f6c-4593-a99f-c5edc2abe443','ca70f843-eadd-4252-9b40-39bc12d334b1','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:19:41',NULL,'2026-09-14 05:24:41','2026-09-14 05:24:41'),
('a05b312d-beca-4569-9395-cb294da50c09','f9f7546f-f81d-4a9c-8ea8-81f98ed86d7a','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('a38c6a99-33b8-4f05-87f8-84d7ac5057b3','e000d455-02f2-4ea4-96e6-5fcb3e6c49ef','2026-09-14','shift_2','kasir',NULL,'08:00:00','23:59:59',NULL,'2026-09-14 05:24:40','2026-09-14 05:24:40'),
('b54e80d6-b321-44ad-94c0-7be12dc35641','5c349b86-3256-4997-8dd7-27db64043774','2026-09-14','shift_1','bar',NULL,'06:50:26','14:50:26',NULL,'2026-09-14 01:50:26','2026-09-14 01:50:26'),
('bef3d805-7f1a-4f2e-a39c-5de6fdc8376a','c2fe3285-9f69-455e-ac7e-765ef0c9ed83','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:06:40',NULL,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('d3f8fd45-fa5f-4ae8-b78f-224267f59875','ba60f984-b76b-422f-9f2e-e33dbd102818','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:21:40',NULL,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('d7849014-e164-47e7-af17-07250c5fb17e','6af10581-93b7-468a-9fdd-8b073fd9d9c9','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:17:40',NULL,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('db786e17-b0ca-487f-a3a2-0e5d2cf163ff','9e786dc3-c19c-4a64-bc83-bedd9bb22352','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:20:37',NULL,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('f4d68374-048d-4232-9bb1-cc5dd8c215a3','12bb1290-c356-4533-91c4-b0203f86973b','2026-09-14','shift_1','kasir',NULL,'06:00:00','12:04:40',NULL,'2026-09-14 05:24:40','2026-09-14 05:24:40'),
('fafd0bf2-a527-4850-a8b9-ad07d5adc874','58949d15-7787-4fc9-a5c2-c7f65648caac','2026-09-14','shift_1','kasir',NULL,'08:00:00','16:00:00',NULL,'2026-09-14 05:26:41','2026-09-14 05:26:41');

/*Table structure for table `karyawan` */

DROP TABLE IF EXISTS `karyawan`;

CREATE TABLE `karyawan` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `role` enum('karyawan','admin','owner') NOT NULL,
  `nama` varchar(150) NOT NULL,
  `email` varchar(150) NOT NULL,
  `nomor_hp` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `foto_profile` text,
  `status_aktif` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `nomor_hp` (`nomor_hp`),
  KEY `idx_karyawan_status_aktif` (`status_aktif`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `karyawan` */

insert  into `karyawan`(`id`,`role`,`nama`,`email`,`nomor_hp`,`password`,`foto_profile`,`status_aktif`,`created_at`,`updated_at`) values 
('0caed65f-5926-401b-9d55-e1ded7b15837','karyawan','Kasir Early V5','early_122506@kyfein.com','0831122506','$2b$12$nrHYW7YeV8qbUPRgMZLEHeiCl9jJ2UNwhtUC.K4iIiig6OFXxng9i',NULL,1,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('12bb1290-c356-4533-91c4-b0203f86973b','karyawan','Kasir Late V5','late_122439@kyfein.com','0832122439','$2b$12$7wTCJhpsS9CtI2JPxj8gr.vb6foyFH5UV7zqXz7qWXvgoySs/TBYO',NULL,1,'2026-09-14 05:24:40','2026-09-14 05:24:40'),
('16fc725c-3298-4a0e-bdf6-ecdcc79d47be','admin','Admin Test','admintest@kyfein.com','0822222222','$2b$12$jn.L2CqUF0Ccm9m9/pF7PuWrnUmggQFbGs/tdJhH58R8PUmo1Xhna',NULL,1,'2026-09-14 01:41:03','2026-09-14 01:41:03'),
('18b2936c-11e9-4a83-8d8f-b333dc3c6b0b','karyawan','Kasir Two V5','k2_122506@kyfein.com','0842122506','$2b$12$2SFmeQz2f4XyIt32LUSGW.93h8sRgCE6CK1s6Iti/LrpktQxMW.De',NULL,1,'2026-09-14 05:25:08','2026-09-14 05:25:08'),
('1b2e3e7c-2118-42a8-ace8-92c27bde427f','karyawan','Kasir Tolerance V5','tol_122620@kyfein.com','0833122620','$2b$12$xGKrXyRCeJiclbUMd7spu.HOUWSXQ81OTRBySi1nboZiUTaxV1gbq',NULL,1,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('1cb0275b-5c0a-40d6-b2ce-6724bde9af71','karyawan','Kasir Two V5','k2_122536@kyfein.com','0842122536','$2b$12$GIvPm673Dyyb3jvksZIZde32kjMToLvp7sVyhZUX9QNv7gfNGZpIC',NULL,1,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('23aa953b-8061-44ac-94d1-2963cc7df998','karyawan','Kasir Two V5','k2_122620@kyfein.com','0842122620','$2b$12$QY/961bHP/Jv2R6RQexcOecMWZZLDLaMcqRKqkAUa7NL1QzxiHd5K',NULL,1,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('54ac7aa7-43e6-46d2-8c41-5c7e8a9f500d','karyawan','Kasir One V5','kasir1_v5@kyfein.com','0833333335','$2b$12$GzYQxmjqWPGxUZc45Gpdm.SLgGKZgCvjfx33evwiTnMEnfWeHGRri',NULL,1,'2026-09-14 05:24:08','2026-09-14 05:24:08'),
('57e1c301-39d5-419b-acbc-4a586aeb5b89','karyawan','Kasir Early V5','early_122620@kyfein.com','0831122620','$2b$12$EJEoL7oTpoBQJT9fRHCPAO1vTeA3go0lYJx3v/rGm6GtJv7/sd84e',NULL,1,'2026-09-14 05:26:20','2026-09-14 05:26:20'),
('58949d15-7787-4fc9-a5c2-c7f65648caac','karyawan','Kasir One V5','k1_122639@kyfein.com','0841122639','$2b$12$ztkz8Yc2B/wcQScIZrphQe1BzsVeFU1XVZ44bTuMCvJcCRF9TB93m',NULL,1,'2026-09-14 05:26:41','2026-09-14 05:26:41'),
('5c349b86-3256-4997-8dd7-27db64043774','karyawan','Kasir Test','kasirtest@kyfein.com','0833333333','$2b$12$Zk9E2zXXCWFAhz7qrx91ZeULKKyVBt0M4WjngrYaNyCkID2mzE7SW',NULL,1,'2026-09-14 01:41:03','2026-09-14 01:53:58'),
('603660d6-d7c3-4c59-85c5-e5b1bc46fe90','karyawan','Kasir Late V5','late_133155@kyfein.com','0832133155','$2b$12$7akOd3yYF84D460DpOET0u4QN7XLP424uXM3l9.Re.IHJyfOlpeNa',NULL,1,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('628c8069-3cc2-4cf9-a308-37983e169b91','karyawan','Kasir Early V5','early_133155@kyfein.com','0831133155','$2b$12$gk6hJm6jJx6aqF4bvBcwGuOWyFpWryR.rlYRi4tbjs3cu25IPj0nO',NULL,1,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('670b5760-1eaf-4590-8faf-60097352172c','karyawan','Kasir Late V5','late_122506@kyfein.com','0832122506','$2b$12$xcKegAhdhMX/61f8aE3JJexrP3ADX5L9GoYDHnKUuBaFIwMpU8lQ.',NULL,1,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('6a314e55-bd26-4ae5-aa0c-e71821968485','karyawan','Kasir One V5','k1_133155@kyfein.com','0841133155','$2b$12$EeH2X.NAeGhccb.MiSMU.OkbV.gN72kEcVQJzxGyiHtwNSk3.reJG',NULL,1,'2026-09-14 06:31:57','2026-09-14 06:31:57'),
('6af10581-93b7-468a-9fdd-8b073fd9d9c9','karyawan','Kasir Late V5','late_123739@kyfein.com','0832123739','$2b$12$NK1OFCiBhnJyBQ4KsRgo3OoZWAabVZZbVYdBEzj26ELio0Nah2OlC',NULL,1,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('6c0a94f5-0f4a-46a3-a320-a5202cff9fa3','karyawan','Kasir One V5','k1_122620@kyfein.com','0841122620','$2b$12$/rboofBR6bREFXsJsZAcv.dRAdRuKnFv0vi2ZN1Lpb3ekiOLuPtjy',NULL,1,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('72787fed-181f-4b1e-a9e8-1aab510d8aff','karyawan','Kasir One V5','k1_122506@kyfein.com','0841122506','$2b$12$3pxNxv3uEyfcjtkmNDWdWuVIMNOeJBsV.R.yyMJwRHmri7qBoN8b6',NULL,1,'2026-09-14 05:25:08','2026-09-14 05:25:08'),
('7d1c9b27-108c-4700-b06b-2c42961e9518','karyawan','Kasir One V5','k1_123739@kyfein.com','0841123739','$2b$12$Xn9s4ErGU1fBOy3Qq2ESyuNdOkLFZN2I7RE0MF9Lu1xNNSYk4hvHq',NULL,1,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('855a933a-af51-4f99-b567-23a0f8f6e97b','karyawan','Kasir Two V5','k2_123739@kyfein.com','0842123739','$2b$12$aSejapjlxdmJx1v.mRsDU.oHHa8v6J2vHM.5RnjiUA5gv1q9eFEOO',NULL,1,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('8bbae7e9-3846-4c9c-91d2-5568abeaefa1','karyawan','Kasir Early V5','early_122536@kyfein.com','0831122536','$2b$12$s99/QJWRH1RveKLJhj3xneZ3oGFxKKITekMU7WfR8V3wODpRCqiru',NULL,1,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('8e63b64c-1530-4017-ad80-25fe07da02c4','karyawan','Kasir Early V5','early_123739@kyfein.com','0831123739','$2b$12$Pr1WGFh29VDp7Br73O2n8OmyzOoBZGhZF7GjSSISWpgptqo/Ub5Qy',NULL,1,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('929f0318-7211-4a32-8811-c3a462c73ee4','karyawan','Kasir Early V5','early_133127@kyfein.com','0831133127','$2b$12$9UXWxp08N.wk.GraaaclE.KjwxOttGrGCKElyOWZAxRGPQroa2ksa',NULL,1,'2026-09-14 06:31:28','2026-09-14 06:31:28'),
('97ce8977-104f-4e58-ab62-9f8e58090016','karyawan','Kasir Late V5','late_122620@kyfein.com','0832122620','$2b$12$2cy.t7Ds8oCN3Btit8.aM.rW0/zKoAMslLbnedtvaoQ8AGjn6t2nG',NULL,1,'2026-09-14 05:26:21','2026-09-14 05:26:21'),
('9e786dc3-c19c-4a64-bc83-bedd9bb22352','karyawan','Kasir Tolerance V5','tol_122536@kyfein.com','0833122536','$2b$12$o4cB5Tx3mDid4nj3.zDwfO6NYSN8KXCzuen818It6O5m7QLnf8fGa',NULL,1,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('9f1f2a1d-1251-4b7e-9053-5f871028f5c6','karyawan','Kasir Two V5','k2_133127@kyfein.com','0842133127','$2b$12$LrofOQXaL5TFaATzb7Ad8ejJf4klv4/UeiJd6IekmEcn2ByVtoepa',NULL,1,'2026-09-14 06:31:29','2026-09-14 06:31:29'),
('a0eb13e2-7bef-4c75-aa2d-19c6b71c8bb3','karyawan','Kasir One V5','k1_122536@kyfein.com','0841122536','$2b$12$NCPAhOxLZFs3NHLGIYLX/.dHw3HiD6G9JjyEi6h6ZMPJuWpUw0ILi',NULL,1,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('a469b01e-77d3-4b07-891f-fe1eafd99902','karyawan','Kasir Two V5','k2_122639@kyfein.com','0842122639','$2b$12$kNmQYf/KM0wVs3s9QQE4Z.4iDL6.4Jflqp9RHxuJyR31XZX5c.1tG',NULL,1,'2026-09-14 05:26:41','2026-09-14 05:26:41'),
('aedbe233-819d-4023-97b5-7fb8610e4f28','owner','Owner Kyfein Cafe','owner@kyfein.cafe','081234567890','$2b$12$Q/Lo.uGBPBcYRvmhg5tt6uyX49A8O.1Lu0dQ52z.O3ehjpTpBUVia',NULL,1,'2026-09-14 07:21:07','2026-09-14 07:21:07'),
('ba60f984-b76b-422f-9f2e-e33dbd102818','karyawan','Kasir Tolerance V5','tol_122639@kyfein.com','0833122639','$2b$12$PXPa1UwmZjeDGmLOciHB7OiOX20AZ394piHN3AX7Ziqh1d/gCe6Pu',NULL,1,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('bb5206e1-ca56-47f2-8458-4964000c9a43','karyawan','Kasir One V5','k1_122439@kyfein.com','0841122439','$2b$12$NqrP/LA.yc2FjuKqe0.yLuPspQBfFS6/OgTfr3P/Sh4JDGfJPEERe',NULL,1,'2026-09-14 05:24:41','2026-09-14 05:24:41'),
('bf5e2bfe-7213-4529-a922-c8fb1c2a0585','karyawan','Kasir Yesterday V5','yest_133155@kyfein.com','0851133155','$2b$12$tf3vWEBue1G8qrUQU1MXJuExLQNuiI2N8SZRExY/XhsYe2T8EGplW',NULL,1,'2026-09-14 06:31:57','2026-09-14 06:31:57'),
('c2fe3285-9f69-455e-ac7e-765ef0c9ed83','karyawan','Kasir Late V5','late_122639@kyfein.com','0832122639','$2b$12$MFQY9hfH9OCpBJGb.GX0POdl3xyW9Sqc3v5l6WabinqooQ.8gfYeK',NULL,1,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('ca70f843-eadd-4252-9b40-39bc12d334b1','karyawan','Kasir Tolerance V5','tol_122439@kyfein.com','0833122439','$2b$12$u7U85t8QfPq2A7eJMa3PAOzlj0UYsqMpPHMaaoaQeI.isz4dyjBGW',NULL,1,'2026-09-14 05:24:41','2026-09-14 05:24:41'),
('d3bc2d67-7d5f-4b34-9f16-6a04a5d6820b','karyawan','Kasir Two V5','k2_133155@kyfein.com','0842133155','$2b$12$sCMXbCBFvYU6ZdRkMJGnYu8Pv9XvNpyDSvOxyGplQ1WwuoDS4tXoK',NULL,1,'2026-09-14 06:31:57','2026-09-14 06:31:57'),
('dd74e1d9-2681-4671-9412-9e136d043b04','karyawan','Kasir Tolerance V5','tol_133127@kyfein.com','0833133127','$2b$12$6uCSXP/cQqD/kVdPIsj91uc0qpei3fFOkFGb5VaT9GVJ4MszKO1jq',NULL,1,'2026-09-14 06:31:29','2026-09-14 06:31:29'),
('ddca7274-87a1-421d-a6bf-37fa031fb017','karyawan','Kasir Two V5','kasir2_v5@kyfein.com','0844444445','$2b$12$o7gbATWUQM01VDIaO/kng.dvP8vPYYwjfK1EktCxlxcGoUL8CpC3G',NULL,1,'2026-09-14 05:24:08','2026-09-14 05:24:08'),
('e000d455-02f2-4ea4-96e6-5fcb3e6c49ef','karyawan','Kasir Early V5','early_122439@kyfein.com','0831122439','$2b$12$9zLfc58tq5VzzwkinS2pfu4AhoBoT1RI6gRTEyPe7qwwnlZGnTogi',NULL,1,'2026-09-14 05:24:40','2026-09-14 05:24:40'),
('e9960509-07ce-4e91-a9c5-54f90687cd4f','karyawan','Kasir Tolerance V5','tol_133155@kyfein.com','0833133155','$2b$12$7I5ecpEYvqC18fBXXzthTuj13cP1IBabQMpt1s6ydypqMY39Q4Wpy',NULL,1,'2026-09-14 06:31:56','2026-09-14 06:31:56'),
('e9d2999c-3476-4206-a9a2-9dfa290fed52','karyawan','Kasir Late V5','late_133127@kyfein.com','0832133127','$2b$12$blpnqb/FMBzSQ.yJh4qRq.sZzpyEvgH7lczWAjYc4X3c2/m5sxH4S',NULL,1,'2026-09-14 06:31:28','2026-09-14 06:31:28'),
('ebc40f6a-49df-4610-9772-9da5ab3b82fb','karyawan','Kasir Tolerance V5','tol_122506@kyfein.com','0833122506','$2b$12$kgWbJiRb6uO98uVeY6.I7OW9n68laPV9Oe8jEVKCzdgpoVUIsnfDy',NULL,1,'2026-09-14 05:25:07','2026-09-14 05:25:07'),
('f81e4578-d711-4d85-87ad-756f24250722','karyawan','Kasir One V5','k1_133127@kyfein.com','0841133127','$2b$12$rf6rnYQhZ2JEWFhCRVO3HeuERSK9QeZw..tRwDcvR29EFLfVBh2FS',NULL,1,'2026-09-14 06:31:29','2026-09-14 06:31:29'),
('f9f7546f-f81d-4a9c-8ea8-81f98ed86d7a','karyawan','Kasir Early V5','early_122639@kyfein.com','0831122639','$2b$12$WqdHFbDpSs8olh.mSSmZw.5JXEGWLHPwjma38izHvWVh6.EaFxguS',NULL,1,'2026-09-14 05:26:40','2026-09-14 05:26:40'),
('fd416f3b-4d64-4cf3-b700-eec83ee93b57','karyawan','Kasir Two V5','k2_122439@kyfein.com','0842122439','$2b$12$GwrYTNb/g11tWILXGr4uqeUhLlQp3r0ImPJJse1pqR3JF.8Hywckm',NULL,1,'2026-09-14 05:24:41','2026-09-14 05:24:41'),
('fdd199fa-30fc-4293-b800-cfb71f109d99','karyawan','Kasir Tolerance V5','tol_123739@kyfein.com','0833123739','$2b$12$9KxGtiHDad4FmbJ.mWcOJ.jACFU8/9EJ4vD.7lrWLaRzhJKqs5elG',NULL,1,'2026-09-14 05:37:40','2026-09-14 05:37:40'),
('fddd2357-e42f-41c6-b5f8-18c5fff47b22','karyawan','Kasir Late V5','late_122536@kyfein.com','0832122536','$2b$12$PkoICq68j45FN3aJN6NtIu3J1dX/NSlnmiffFa4.PUOQSc3QD4FfS',NULL,1,'2026-09-14 05:25:37','2026-09-14 05:25:37');

/*Table structure for table `kategori_menu` */

DROP TABLE IF EXISTS `kategori_menu`;

CREATE TABLE `kategori_menu` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `nama` varchar(50) NOT NULL,
  `area_produksi` enum('bar','kitchen') NOT NULL,
  `status_aktif` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `nama` (`nama`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `kategori_menu` */

insert  into `kategori_menu`(`id`,`nama`,`area_produksi`,`status_aktif`,`created_at`) values 
('cce6a954-247d-4258-a7d9-436b25e3c2fb','Test Kat V5','bar',1,'2026-09-14 05:25:08'),
('f67e535f-af8a-11f1-a2f5-0a0027000008','Makanan','kitchen',1,'2026-09-13 22:51:20'),
('f67e5e26-af8a-11f1-a2f5-0a0027000008','Minuman','bar',1,'2026-09-13 22:51:20');

/*Table structure for table `kategori_pengeluaran` */

DROP TABLE IF EXISTS `kategori_pengeluaran`;

CREATE TABLE `kategori_pengeluaran` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `nama` varchar(50) NOT NULL,
  `status_aktif` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `nama` (`nama`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `kategori_pengeluaran` */

/*Table structure for table `konfigurasi_lokasi` */

DROP TABLE IF EXISTS `konfigurasi_lokasi`;

CREATE TABLE `konfigurasi_lokasi` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `latitude` decimal(11,8) NOT NULL,
  `longitude` decimal(11,8) NOT NULL,
  `radius_meter` int NOT NULL DEFAULT '50',
  `updated_by` char(36) DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `konfigurasi_lokasi` */

/*Table structure for table `menu` */

DROP TABLE IF EXISTS `menu`;

CREATE TABLE `menu` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `nama` varchar(100) NOT NULL,
  `kode_menu` varchar(20) NOT NULL,
  `harga` decimal(14,2) NOT NULL DEFAULT '0.00',
  `kategori_id` char(36) NOT NULL,
  `foto` text,
  `status_aktif` tinyint(1) NOT NULL DEFAULT '1',
  `dibuat_oleh` char(36) DEFAULT NULL,
  `diubah_oleh` char(36) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `kode_menu` (`kode_menu`),
  KEY `idx_menu_kategori` (`kategori_id`),
  KEY `idx_menu_status_aktif` (`status_aktif`),
  CONSTRAINT `menu_chk_1` CHECK ((`harga` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `menu` */

insert  into `menu`(`id`,`nama`,`kode_menu`,`harga`,`kategori_id`,`foto`,`status_aktif`,`dibuat_oleh`,`diubah_oleh`,`created_at`,`updated_at`) values 
('93f9eab1-5b96-4b40-8634-5c9c248594cc','Kopi Test V5','MNU-V5-122536',25000.00,'cce6a954-247d-4258-a7d9-436b25e3c2fb',NULL,1,NULL,NULL,'2026-09-14 05:25:37','2026-09-14 05:25:37'),
('a1618064-28c3-47aa-ad54-fc1f0b9b2b89','Es Teh V5 Without Recipe','MNU-NORESEP-133155',10000.00,'cce6a954-247d-4258-a7d9-436b25e3c2fb',NULL,1,NULL,NULL,'2026-09-14 06:31:57','2026-09-14 06:31:57');

/*Table structure for table `menu_resep` */

DROP TABLE IF EXISTS `menu_resep`;

CREATE TABLE `menu_resep` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `menu_id` char(36) NOT NULL,
  `bahan_id` char(36) NOT NULL,
  `jumlah_terpakai` decimal(10,3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_menu_resep` (`menu_id`,`bahan_id`),
  KEY `idx_menu_resep_menu` (`menu_id`),
  KEY `idx_menu_resep_bahan` (`bahan_id`),
  CONSTRAINT `menu_resep_ibfk_1` FOREIGN KEY (`menu_id`) REFERENCES `menu` (`id`) ON DELETE CASCADE,
  CONSTRAINT `menu_resep_chk_1` CHECK ((`jumlah_terpakai` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `menu_resep` */

/*Table structure for table `mutasi_stok` */

DROP TABLE IF EXISTS `mutasi_stok`;

CREATE TABLE `mutasi_stok` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `bahan_id` char(36) NOT NULL,
  `titik` enum('bar','kitchen') DEFAULT NULL,
  `jadwal_shift_id` char(36) DEFAULT NULL,
  `tipe` varchar(50) NOT NULL DEFAULT 'selisih_handover',
  `jumlah_selisih` decimal(10,3) NOT NULL,
  `keterangan` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mutasi_stok_bahan` (`bahan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `mutasi_stok` */

/*Table structure for table `pengeluaran` */

DROP TABLE IF EXISTS `pengeluaran`;

CREATE TABLE `pengeluaran` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `kategori_id` char(36) NOT NULL,
  `tipe` enum('bulanan','mendadak') NOT NULL,
  `nominal` decimal(14,2) NOT NULL,
  `bulan` date DEFAULT NULL,
  `tanggal` date DEFAULT NULL,
  `keterangan` text,
  `dicatat_oleh` char(36) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pengeluaran_bulan` (`bulan`),
  KEY `idx_pengeluaran_tanggal` (`tanggal`),
  KEY `idx_pengeluaran_kategori` (`kategori_id`),
  CONSTRAINT `chk_pengeluaran_periode` CHECK ((((`tipe` = _utf8mb4'bulanan') and (`bulan` is not null) and (`tanggal` is null)) or ((`tipe` = _utf8mb4'mendadak') and (`tanggal` is not null) and (`bulan` is null)))),
  CONSTRAINT `pengeluaran_chk_1` CHECK ((`nominal` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `pengeluaran` */

/*Table structure for table `request_off` */

DROP TABLE IF EXISTS `request_off`;

CREATE TABLE `request_off` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `karyawan_id` char(36) NOT NULL,
  `tanggal` date NOT NULL,
  `alasan` text,
  `diajukan_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_request_off_karyawan` (`karyawan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `request_off` */

/*Table structure for table `shift_template` */

DROP TABLE IF EXISTS `shift_template`;

CREATE TABLE `shift_template` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `shift` enum('shift_1','shift_2') NOT NULL,
  `jam_mulai` time NOT NULL,
  `jam_selesai` time NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `shift` (`shift`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `shift_template` */

insert  into `shift_template`(`id`,`shift`,`jam_mulai`,`jam_selesai`,`updated_at`) values 
('f67dca47-af8a-11f1-a2f5-0a0027000008','shift_1','08:00:00','16:00:00','2026-09-13 22:51:20'),
('f67e1818-af8a-11f1-a2f5-0a0027000008','shift_2','16:00:00','23:00:00','2026-09-13 22:51:20');

/*Table structure for table `stok_gudang` */

DROP TABLE IF EXISTS `stok_gudang`;

CREATE TABLE `stok_gudang` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `bahan_id` char(36) NOT NULL,
  `jumlah_kemasan_besar` int NOT NULL DEFAULT '0',
  `jumlah_satuan_kecil` decimal(10,3) NOT NULL DEFAULT '0.000',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `bahan_id` (`bahan_id`),
  KEY `idx_stok_gudang_bahan` (`bahan_id`),
  CONSTRAINT `stok_gudang_chk_1` CHECK ((`jumlah_kemasan_besar` >= 0)),
  CONSTRAINT `stok_gudang_chk_2` CHECK ((`jumlah_satuan_kecil` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `stok_gudang` */

insert  into `stok_gudang`(`id`,`bahan_id`,`jumlah_kemasan_besar`,`jumlah_satuan_kecil`,`updated_at`) values 
('0fe3c656-3d2d-4960-bf59-bca834b81d72','dad439fd-c5e3-41d0-9be0-23027c9cd93f',3,0.000,'2026-09-14 01:53:58');

/*Table structure for table `stok_opname` */

DROP TABLE IF EXISTS `stok_opname`;

CREATE TABLE `stok_opname` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `jadwal_shift_id` char(36) NOT NULL,
  `titik` enum('bar','kitchen') NOT NULL,
  `tipe` enum('awal_shift','akhir_shift') NOT NULL,
  `metode` enum('hitung_manual','carry_forward') NOT NULL,
  `karyawan_id` char(36) NOT NULL,
  `waktu_opname` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `catatan` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stok_opname` (`jadwal_shift_id`,`titik`,`tipe`),
  KEY `idx_stok_opname_jadwal_shift` (`jadwal_shift_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `stok_opname` */

insert  into `stok_opname`(`id`,`jadwal_shift_id`,`titik`,`tipe`,`metode`,`karyawan_id`,`waktu_opname`,`catatan`,`created_at`) values 
('c1154fd5-4b8c-4846-91aa-0804168eb33f','b54e80d6-b321-44ad-94c0-7be12dc35641','bar','awal_shift','hitung_manual','5c349b86-3256-4997-8dd7-27db64043774','2026-09-14 01:53:58',NULL,'2026-09-14 01:53:58');

/*Table structure for table `stok_opname_detail` */

DROP TABLE IF EXISTS `stok_opname_detail`;

CREATE TABLE `stok_opname_detail` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `stok_opname_id` char(36) NOT NULL,
  `bahan_id` char(36) NOT NULL,
  `jumlah` decimal(10,3) NOT NULL DEFAULT '0.000',
  PRIMARY KEY (`id`),
  KEY `idx_stok_opname_detail_opname` (`stok_opname_id`),
  CONSTRAINT `stok_opname_detail_ibfk_1` FOREIGN KEY (`stok_opname_id`) REFERENCES `stok_opname` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `stok_opname_detail` */

insert  into `stok_opname_detail`(`id`,`stok_opname_id`,`bahan_id`,`jumlah`) values 
('ef43bd7f-fe0d-4448-9e90-430f808d5308','c1154fd5-4b8c-4846-91aa-0804168eb33f','dad439fd-c5e3-41d0-9be0-23027c9cd93f',500.000);

/*Table structure for table `stok_titik` */

DROP TABLE IF EXISTS `stok_titik`;

CREATE TABLE `stok_titik` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `bahan_id` char(36) NOT NULL,
  `titik` enum('bar','kitchen') NOT NULL,
  `jumlah` decimal(10,3) NOT NULL DEFAULT '0.000',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stok_titik` (`bahan_id`,`titik`),
  KEY `idx_stok_titik_bahan` (`bahan_id`),
  CONSTRAINT `stok_titik_chk_1` CHECK ((`jumlah` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `stok_titik` */

insert  into `stok_titik`(`id`,`bahan_id`,`titik`,`jumlah`,`updated_at`) values 
('9029271b-76e2-4a56-99dd-cee32e4ced80','dad439fd-c5e3-41d0-9be0-23027c9cd93f','bar',500.000,'2026-09-14 01:51:55');

/*Table structure for table `transaksi` */

DROP TABLE IF EXISTS `transaksi`;

CREATE TABLE `transaksi` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `jadwal_shift_id` char(36) NOT NULL,
  `kasir_id` char(36) NOT NULL,
  `nomor_transaksi` varchar(30) NOT NULL,
  `metode_bayar` enum('cash','qris') NOT NULL,
  `total_harga` decimal(14,2) NOT NULL DEFAULT '0.00',
  `uang_diterima` decimal(14,2) DEFAULT NULL,
  `kembalian` decimal(14,2) DEFAULT NULL,
  `foto_bukti_qris` text,
  `status` enum('selesai','dibatalkan') NOT NULL DEFAULT 'selesai',
  `waktu_transaksi` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `nomor_transaksi` (`nomor_transaksi`),
  KEY `idx_transaksi_waktu` (`waktu_transaksi`),
  KEY `idx_transaksi_jadwal_shift` (`jadwal_shift_id`),
  KEY `idx_transaksi_kasir` (`kasir_id`),
  KEY `idx_transaksi_status` (`status`),
  CONSTRAINT `chk_bukti_bayar` CHECK ((((`metode_bayar` = _utf8mb4'cash') and (`uang_diterima` is not null)) or ((`metode_bayar` = _utf8mb4'qris') and (`foto_bukti_qris` is not null)))),
  CONSTRAINT `transaksi_chk_1` CHECK ((`total_harga` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `transaksi` */

insert  into `transaksi`(`id`,`jadwal_shift_id`,`kasir_id`,`nomor_transaksi`,`metode_bayar`,`total_harga`,`uang_diterima`,`kembalian`,`foto_bukti_qris`,`status`,`waktu_transaksi`,`created_at`) values 
('0e4a280a-fbb6-4240-a92d-92e2c71eb94b','7e74e8b6-e587-4ef7-ba42-5234d56c02d3','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-C2B6E0','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 06:31:57','2026-09-14 06:31:57'),
('3f4acb5b-39f9-4219-a12c-bc217cba7b16','48aeb7c3-24c8-43f4-b173-bade53dec540','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-6320BB','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 06:31:29','2026-09-14 06:31:29'),
('57b19764-5527-4c73-be9c-22911a1a5001','4e919c38-bc51-4db5-b7ca-650ca239bda6','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-4AC605','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 05:26:21','2026-09-14 05:26:21'),
('73ddfaa0-00df-44ec-b19e-df4b73285d5c','fafd0bf2-a527-4850-a8b9-ad07d5adc874','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-7A443F','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 05:26:41','2026-09-14 05:26:41'),
('91c2dccf-54b8-44cf-8204-be8e6a4e900b','7e74e8b6-e587-4ef7-ba42-5234d56c02d3','6a314e55-bd26-4ae5-aa0c-e71821968485','TRX-TEST-V5-133156','cash',10000.00,10000.00,0.00,NULL,'selesai','2026-09-14 13:31:57','2026-09-14 06:31:57'),
('b1f08d1a-6302-4426-b2fd-7421c4035572','17355860-fb84-4a45-9d85-63f8c840acd4','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-F79F64','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 05:37:40','2026-09-14 05:37:40'),
('cec71cf8-7c3f-496b-9984-033f6aca6d92','94e9e004-ff3a-422f-8a4b-a8293222b031','16fc725c-3298-4a0e-bdf6-ecdcc79d47be','TRX-20260914-33738D','cash',25000.00,30000.00,5000.00,NULL,'selesai','2026-09-14 05:25:37','2026-09-14 05:25:37');

/*Table structure for table `transaksi_detail` */

DROP TABLE IF EXISTS `transaksi_detail`;

CREATE TABLE `transaksi_detail` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `transaksi_id` char(36) NOT NULL,
  `menu_id` char(36) NOT NULL,
  `qty` int NOT NULL,
  `harga_satuan` decimal(14,2) NOT NULL,
  `catatan` text,
  `subtotal` decimal(14,2) NOT NULL,
  `status_item` enum('menunggu','diproses','selesai') NOT NULL DEFAULT 'menunggu',
  PRIMARY KEY (`id`),
  KEY `idx_transaksi_detail_transaksi` (`transaksi_id`),
  KEY `idx_transaksi_detail_menu` (`menu_id`),
  KEY `idx_transaksi_detail_status_item` (`status_item`),
  CONSTRAINT `transaksi_detail_ibfk_1` FOREIGN KEY (`transaksi_id`) REFERENCES `transaksi` (`id`) ON DELETE CASCADE,
  CONSTRAINT `transaksi_detail_chk_1` CHECK ((`qty` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `transaksi_detail` */

insert  into `transaksi_detail`(`id`,`transaksi_id`,`menu_id`,`qty`,`harga_satuan`,`catatan`,`subtotal`,`status_item`) values 
('0d251377-f2ee-4d4c-8484-17f7826bef5e','73ddfaa0-00df-44ec-b19e-df4b73285d5c','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('21fd9902-6adc-4aa5-b935-23d087dda352','b1f08d1a-6302-4426-b2fd-7421c4035572','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('5a5e53ad-432b-4e27-b863-502cb6f135ae','57b19764-5527-4c73-be9c-22911a1a5001','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('64e77c10-cfc8-4d99-bb2d-ae914fdcccbf','cec71cf8-7c3f-496b-9984-033f6aca6d92','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('aaea749f-3545-4b79-a81d-28ac371a5978','3f4acb5b-39f9-4219-a12c-bc217cba7b16','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('c05cc8cf-3d6f-477b-b772-6d5fb3fbd6cf','0e4a280a-fbb6-4240-a92d-92e2c71eb94b','93f9eab1-5b96-4b40-8634-5c9c248594cc',1,25000.00,NULL,25000.00,'menunggu'),
('e83d093d-73f4-4c1a-a15d-b312433b50b1','91c2dccf-54b8-44cf-8204-be8e6a4e900b','a1618064-28c3-47aa-ad54-fc1f0b9b2b89',1,10000.00,NULL,10000.00,'selesai');

/*Table structure for table `tukar_shift` */

DROP TABLE IF EXISTS `tukar_shift`;

CREATE TABLE `tukar_shift` (
  `id` char(36) NOT NULL DEFAULT (uuid()),
  `shift_a_id` char(36) NOT NULL,
  `shift_b_id` char(36) NOT NULL,
  `karyawan_pengaju_id` char(36) NOT NULL,
  `karyawan_target_id` char(36) NOT NULL,
  `status` enum('pending','disetujui','ditolak') NOT NULL DEFAULT 'pending',
  `alasan` text,
  `diajukan_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `diproses_oleh` char(36) DEFAULT NULL,
  `diproses_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_tukar_shift_shift_a` (`shift_a_id`),
  KEY `idx_tukar_shift_shift_b` (`shift_b_id`),
  KEY `idx_tukar_shift_status` (`status`),
  CONSTRAINT `chk_tukar_shift_beda_row` CHECK ((`shift_a_id` <> `shift_b_id`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

/*Data for the table `tukar_shift` */

/* Trigger structure for table `konfigurasi_lokasi` */

DELIMITER $$

/*!50003 DROP TRIGGER*//*!50032 IF EXISTS */ /*!50003 `trg_audit_konfigurasi_lokasi` */$$

/*!50003 CREATE */ /*!50017 DEFINER = 'root'@'localhost' */ /*!50003 TRIGGER `trg_audit_konfigurasi_lokasi` AFTER UPDATE ON `konfigurasi_lokasi` FOR EACH ROW BEGIN
    INSERT INTO audit_log_konfigurasi (tabel, row_id, data_lama, data_baru, diubah_oleh)
    VALUES (
        'konfigurasi_lokasi',
        NEW.id,
        JSON_OBJECT('latitude', OLD.latitude, 'longitude', OLD.longitude, 'radius_meter', OLD.radius_meter, 'updated_by', OLD.updated_by),
        JSON_OBJECT('latitude', NEW.latitude, 'longitude', NEW.longitude, 'radius_meter', NEW.radius_meter, 'updated_by', NEW.updated_by),
        NEW.updated_by
    );
END */$$


DELIMITER ;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
