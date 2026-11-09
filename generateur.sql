SET search_path TO rail;

TRUNCATE station, line, train, traveler RESTART IDENTITY CASCADE;

INSERT INTO station (name)
SELECT 'Station ' || station_num
FROM generate_series(1, 27) AS station_num;

INSERT INTO line (line_number, name)
SELECT line_num, 'Line ' || line_num
FROM generate_series(1, 12) AS line_num;

INSERT INTO line_stop (line_number, station_id, position_on_line, distance_from_next)
SELECT line_num, (line_num - 1) * 2 + position, position, CASE WHEN position = 5 THEN 0 ELSE 20 END
FROM generate_series(1, 12) AS line_num
CROSS JOIN generate_series(1, 5) AS position;

INSERT INTO train (train_number, avg_speed_kmh)
SELECT train_num, 100
FROM generate_series(1, 12) AS train_num;

INSERT INTO wagon (train_number, wagon_number)
SELECT train_num, wagon_num
FROM generate_series(1, 12) AS train_num
CROSS JOIN generate_series(1, 4) AS wagon_num;

INSERT INTO seat (wagon_id, seat_number, class)
SELECT wagon_id, seat_num, CASE WHEN wagon_number = 1 THEN 'FIRST' ELSE 'SECOND' END
FROM wagon
CROSS JOIN generate_series(1, 20) AS seat_num;

INSERT INTO traveler (first_name, last_name, email)
SELECT 'First' || traveler_num, 'Last' || traveler_num, 'traveler' || traveler_num || '@mail.fr'
FROM generate_series(1, 1000) AS traveler_num;

INSERT INTO journey (journey_number, train_number, line_number, departure_time, schedule)
SELECT line_num * 10 + slot.num, line_num, line_num, slot.start_time, slot.schedule
FROM generate_series(1, 12) AS line_num
CROSS JOIN (VALUES (1, TIME '07:00', 'EVERY_DAY'),
                   (2, TIME '12:00', 'EVERY_DAY'),
                   (3, TIME '17:00', 'WEEKDAYS')) AS slot (num, start_time, schedule);

INSERT INTO journey_stop (journey_number, station_id, stop_order, arrival_time, departure_time)
SELECT journey_number, station_id, position_on_line,
       CASE WHEN position_on_line = 1 THEN NULL ELSE stop_time END,
       CASE WHEN position_on_line = 5 THEN NULL ELSE stop_time + INTERVAL '2 minutes' END
FROM (
    SELECT j.journey_number, ls.station_id, ls.position_on_line,
           j.departure_time + (ls.position_on_line - 1) * INTERVAL '15 minutes' AS stop_time
    FROM journey j
    JOIN line_stop ls ON ls.line_number = j.line_number
) AS stops
ORDER BY journey_number, position_on_line;


INSERT INTO reservation (journey_number, traveler_id, seat_id, departure_station_id, arrival_station_id,
                         departure_datetime, travel_time_minutes, price_cents, reserved_at)
SELECT j.journey_number,
       1 + floor(random() * 1000)::int,
       s.seat_id,
       first_stop.station_id,
       last_stop.station_id,
       days.day + j.departure_time,
       60,
       CASE WHEN s.class = 'FIRST' THEN 1500 ELSE 1000 END,
       days.day + j.departure_time - INTERVAL '7 days'
FROM (
    SELECT day::date AS day,
           extract(isodow FROM day) >= 6 AS is_weekend,
           extract(isodow FROM day) IN (5, 7) AS is_busy
    FROM generate_series(DATE '2026-01-01', DATE '2026-12-31', INTERVAL '1 day') AS day
) AS days
JOIN journey j ON j.schedule = 'EVERY_DAY'
              OR (j.schedule = 'WEEKDAYS' AND NOT days.is_weekend)
JOIN wagon w ON w.train_number = j.train_number
JOIN seat s ON s.wagon_id = w.wagon_id
JOIN journey_stop first_stop ON first_stop.journey_number = j.journey_number AND first_stop.stop_order = 1
JOIN journey_stop last_stop ON last_stop.journey_number = j.journey_number AND last_stop.stop_order = 5
WHERE days.is_busy OR s.seat_number <= 12;

SELECT count(*) AS reservations FROM reservation;
