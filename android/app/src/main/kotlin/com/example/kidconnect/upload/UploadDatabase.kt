package com.example.kidconnect.upload

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [UploadJob::class], version = 2, exportSchema = false)
abstract class UploadDatabase : RoomDatabase() {
    abstract fun uploadDao(): UploadDao

    companion object {
        @Volatile
        private var INSTANCE: UploadDatabase? = null

        fun getInstance(context: Context): UploadDatabase {
            return INSTANCE ?: synchronized(this) {
                val MIGRATION_1_2 = object : androidx.room.migration.Migration(1, 2) {
                    override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                        database.execSQL("ALTER TABLE upload_jobs ADD COLUMN totalBytes INTEGER NOT NULL DEFAULT 0")
                        database.execSQL("ALTER TABLE upload_jobs ADD COLUMN uploadedBytes INTEGER NOT NULL DEFAULT 0")
                        database.execSQL("ALTER TABLE upload_jobs ADD COLUMN isPaused INTEGER NOT NULL DEFAULT 0")
                        database.execSQL("ALTER TABLE upload_jobs ADD COLUMN isCancelled INTEGER NOT NULL DEFAULT 0")
                    }
                }

                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    UploadDatabase::class.java,
                    "upload_database"
                ).addMigrations(MIGRATION_1_2).build()
                INSTANCE = instance
                instance
            }
        }
    }
}
