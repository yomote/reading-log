-- CreateTable
CREATE TABLE `Reading` (
    `id` VARCHAR(191) NOT NULL,
    `title` VARCHAR(191) NOT NULL,
    `author` VARCHAR(191) NOT NULL,
    `link` VARCHAR(191) NOT NULL,
    `pubDate` VARCHAR(191) NOT NULL,
    `isbn` VARCHAR(191) NULL,
    `jpno` VARCHAR(191) NULL,
    `status` VARCHAR(191) NOT NULL DEFAULT 'unread',
    `note` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
