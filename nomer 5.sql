START TRANSACTION;

-- CTE untuk menentukan ranking siswa priority 1 dan kandidat final
WITH temp_priority_1 AS (
  SELECT 
      r.id_registration,
      r.user_id_user,
      r.school_registration_path_school_id_school AS school_id,
      r.school_registration_path_registration_path_id_registration_path AS path_id,
      sr.score,
      ROW_NUMBER() OVER (
          PARTITION BY r.school_registration_path_school_id_school, 
                       r.school_registration_path_registration_path_id_registration_path
          ORDER BY sr.score DESC
      ) AS ranking
  FROM registration r
  JOIN selection_result sr 
      ON r.id_registration = sr.registration_id_registration
  WHERE r.priority = 1 
    AND sr.status = 'lolos'
),

final_candidates AS (
  SELECT 
      t.id_registration,
      t.score
  FROM temp_priority_1 t
  JOIN school_registration_path srp
    ON t.school_id = srp.school_id_school 
   AND t.path_id = srp.registration_path_id_registration_path
  WHERE t.ranking <= (srp.capacity - srp.used_capacity)
)

-- Insert kandidat final ke final_result
INSERT INTO final_result (selection_result_registration_id_registration, score, status)
SELECT id_registration, score, 'lolos'
FROM final_candidates;

-- CTE untuk menghitung jumlah siswa yang diterima per sekolah dan jalur
WITH final_counts AS (
  SELECT 
      r.school_registration_path_school_id_school AS school_id,
      r.school_registration_path_registration_path_id_registration_path AS path_id,
      COUNT(*) AS jumlah_lolos
  FROM final_result fr
  JOIN registration r 
      ON fr.selection_result_registration_id_registration = r.id_registration
  WHERE r.priority = 1
  GROUP BY r.school_registration_path_school_id_school, 
           r.school_registration_path_registration_path_id_registration_path
)
-- Update used_capacity di school_registration_path berdasarkan jumlah siswa yang diterima
UPDATE school_registration_path srp
JOIN final_counts fc 
  ON srp.school_id_school = fc.school_id
 AND srp.registration_path_id_registration_path = fc.path_id
SET srp.used_capacity = srp.used_capacity + fc.jumlah_lolos;








-- Update status pendaftaran priority > 1 
-- untuk siswa yang sudah diterima (final_result)
UPDATE selection_result sr
JOIN registration r 
  ON sr.registration_id_registration = r.id_registration
SET sr.status = 'tidak lolos'
WHERE r.user_id_user IN (
    SELECT DISTINCT user_id_user FROM final_result
)
  AND r.priority > 1;

COMMIT;
