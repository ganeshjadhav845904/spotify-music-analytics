USE [Spotify DB]
GO


-- ============================================
-- DATA PREVIEW
-- ============================================
SELECT * FROM dbo.Spotify_data_sql;
SELECT TOP 10 * FROM dbo.Spotify_data_sql;



-- =============================================
-- DATA CLEANING
-- ============================================

-- 1. Checking Null Vaues
-- =============================================
SELECT * 
FROM dbo.Spotify_data_sql
WHERE song IS NULL
	OR artist IS NULL;


--2. Remove duplicates
-- =============================================
SELECT song, artist, date, COUNT(*) AS cnt
FROM Spotify_data_sql
GROUP BY song, artist, date
HAVING COUNT(*) > 1;


-- 3. Removing true duplicates
-- =============================================
WITH cte AS (
	SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY song, artist, date
			ORDER BY popularity DESC
			) AS rn
	FROM Spotify_data_sql
)
DELETE FROM cte
WHERE rn > 1;


-- 4. Checking NULL values
-- ============================================
SELECT * 
FROM Spotify_data_sql
WHERE song IS NULL
	OR artist IS NULL;


-- 5. FIX DATE COLUMN
-- ============================================
ALTER TABLE Spotify_data_sql
ADD release_date_clean DATE;

UPDATE Spotify_data_sql
SET release_date_clean = TRY_CONVERT(DATE, release_date);

-- Cheking date format
SELECT DISTINCT release_date
FROM Spotify_data_sql;

-- Updating date format
UPDATE Spotify_data_sql
SET release_date_clean = TRY_CONVERT(DATE, release_date, 120);

-- cheking converted null
SELECT *
FROM Spotify_data_sql
WHERE release_date_clean IS NULL;

-- so some dates has only yyyy-mm, so converting it into the yyyy-mm-dd format
UPDATE Spotify_data_sql
SET release_date_clean = 
	CASE
		WHEN LEN(release_date) = 7 THEN
			TRY_CONVERT(DATE, release_date + '-01')
		ELSE
			TRY_CONVERT(DATE, release_date)
	END;

-- verifying after changes
SELECT *
FROM Spotify_data_sql
WHERE release_date_clean IS NULL;


-- ==================================================
-- DATA ANALYSIS
-- ==================================================


-- 1. BASIC ANALYSIS
-- ==================================================

-- 1.1 Top 10 songs by popularity
SELECT TOP 10 song, artist, popularity
FROM Spotify_data_sql
ORDER BY popularity DESC;

-- 1.2 Top artist by number of songs
SELECT artist, COUNT(*) AS total_songs
FROM Spotify_data_sql
GROUP BY artist
ORDER BY total_songs DESC;

-- 1.3 Average song duration
SELECT AVG(duration_ms)/1000 AS avg_duration_seconds
FROM Spotify_data_sql;
-- okay so this is showing empty col, cheking data type and convert it into int.

EXEC sp_help 'Spotify_data_sql';

SELECT TOP 20 duration_ms
FROM Spotify_data_sql;

-- okay so real cause is it exceds the int limit when doing of sum for calculating average, so converting into the bigger data type.
-- use of BIGINT
ALTER TABLE Spotify_data_sql
ALTER COLUMN duration_ms BIGINT;

-- Now finding average song duraion
SELECT AVG(duration_ms)/1000 AS avg_duration_seconds
FROM Spotify_data_sql;


-- 2. Intermediate Anlaysis
-- =====================================================

-- 2.1 Most popular song per day
SELECT date, song, artist, popularity
FROM (
	SELECT *, 
		RANK() OVER ( PARTITION BY date ORDER BY popularity DESC) AS rnk
	FROM Spotify_data_sql
) t
WHERE rnk = 1;

-- 2.2 Explilcit vs Non-explicit sogs
SELECT is_explicit, COUNT(*) AS total
FROM Spotify_data_sql
GROUP BY is_explicit;

-- 2.3 Albul type distribution
SELECT album_type, COUNT(*)
FROM Spotify_data_sql
GROUP BY album_type;

-- 2.4 Top song for each Artist (Best performing song)
SELECT artist, song, popularity
FROM (
	SELECT *, 
		ROW_NUMBER() OVER (PARTITION BY artist ORDER BY popularity DESC) AS rn
	FROM Spotify_data_sql
) t
WHERE rn = 1;

-- 2.5 Artist with consitently high popularity
SELECT artist,
	AVG(popularity) AS avg_popularity,
	COUNT(*) AS total_songs
FROM Spotify_data_sql
GROUP BY artist
HAVING COUNT(*) >= 2
ORDER BY avg_popularity DESC;


-- 3. Advanced Analysis
-- =====================================================

-- 3.1 Ranking songs within each artist
SELECT artist, song, popularity,
	RANK() OVER (PARTITION BY artist ORDER BY popularity DESC) AS rank_in_artist
FROM Spotify_data_sql;

-- 3.2 Top artist based on average popularity
SELECT artist, AVG(popularity) AS avg_popularity
FROM Spotify_data_sql
GROUP BY artist
ORDER BY avg_popularity DESC;

-- 3.3 Trend analysis (song over time)
SELECT date, COUNT(*) AS total_songs
FROM Spotify_data_sql
GROUP BY date
ORDER BY date;

-- 3.4 Most volatile songs (Ubnstable Popularity)
WITH popularity_change AS (
	SELECT song, artist,
		ABS(popularity - LAG(popularity) OVER (PARTITION BY song ORDER BY date)) AS change_val
	FROM Spotify_data_sql
)
SELECT song, artist, AVG(change_val) AS avg_change
FROM popularity_change
GROUP BY song, artist
ORDER BY avg_change DESC;

-- Here I got the error arithmetic overflow error converting expression to data type tinyint, because tinyint only allows value<255, so we have to change the data type.
EXEC sp_help spotify_data_sql; -- cheking data type

-- converting the data type
ALTER TABLE Spotify_data_sql
ALTER COLUMN popularity BIGINT;

-- Now recalculating most volatile song
WITH popularity_change AS (
	SELECT song, artist,
		ABS(popularity - LAG(popularity) OVER (PARTITION BY song ORDER BY date)) AS change_val
	FROM Spotify_data_sql
)
SELECT song, artist, AVG(change_val) AS avg_change
FROM popularity_change
GROUP BY song, artist
ORDER BY avg_change DESC;
-- So error solved

-- 4.5 Songs that improved over time
SELECT song, artist,
	MIN(POSITION) as best_rank,
	MAX(POSITION) as worst_rank
FROM Spotify_data_sql
GROUP BY song, artist
HAVING MIN(position) < MAX(position);