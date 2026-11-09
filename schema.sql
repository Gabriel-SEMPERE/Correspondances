DROP SCHEMA IF EXISTS rail CASCADE;
CREATE SCHEMA rail;
SET search_path TO rail;

CREATE TABLE station (
    station_id SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE line (
    line_number INTEGER PRIMARY KEY CHECK (line_number > 0),
    name        VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE line_stop (
    line_stop_id      SERIAL PRIMARY KEY,
    line_number       INTEGER NOT NULL REFERENCES line (line_number) ON DELETE CASCADE,
    station_id        INTEGER NOT NULL REFERENCES station (station_id) ON DELETE RESTRICT,
    position_on_line  INTEGER NOT NULL CHECK (position_on_line > 0),
    distance_from_next INTEGER NOT NULL DEFAULT 0 CHECK (distance_from_next >= 0),
    CONSTRAINT uq_line_stop_position UNIQUE (line_number, position_on_line),
    CONSTRAINT uq_line_stop_station UNIQUE (line_number, station_id)
);

CREATE TABLE train (
    train_number  INTEGER PRIMARY KEY CHECK (train_number > 0),
    avg_speed_kmh NUMERIC(5,1) NOT NULL CHECK (avg_speed_kmh > 0)
);

CREATE TABLE wagon (
    wagon_id     SERIAL PRIMARY KEY,
    train_number INTEGER NOT NULL REFERENCES train (train_number) ON DELETE CASCADE,
    wagon_number INTEGER NOT NULL CHECK (wagon_number > 0),
    CONSTRAINT uq_wagon_in_train UNIQUE (train_number, wagon_number)
);

CREATE TABLE seat (
    seat_id     SERIAL PRIMARY KEY,
    wagon_id    INTEGER NOT NULL REFERENCES wagon (wagon_id) ON DELETE CASCADE,
    seat_number INTEGER NOT NULL CHECK (seat_number > 0),
    class       VARCHAR(10) NOT NULL DEFAULT 'SECOND' CHECK (class IN ('FIRST', 'SECOND')),
    CONSTRAINT uq_seat_in_wagon UNIQUE (wagon_id, seat_number)
);

CREATE TABLE traveler (
    traveler_id SERIAL PRIMARY KEY,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    email       VARCHAR(150) NOT NULL UNIQUE,
    profile     VARCHAR(20) NOT NULL DEFAULT 'FULL_PRICE'
                CHECK (profile IN ('FULL_PRICE', 'YOUNG', 'SENIOR', 'SUBSCRIBER'))
);

CREATE TABLE journey (
    journey_number    INTEGER PRIMARY KEY CHECK (journey_number > 0),
    train_number      INTEGER NOT NULL REFERENCES train (train_number) ON DELETE RESTRICT,
    line_number       INTEGER NOT NULL REFERENCES line (line_number) ON DELETE RESTRICT,
    departure_time    TIME NOT NULL,
    stop_time_minutes INTEGER NOT NULL DEFAULT 2 CHECK (stop_time_minutes >= 0),
    default_direction BOOLEAN NOT NULL DEFAULT TRUE,
    is_direct         BOOLEAN NOT NULL DEFAULT FALSE,
    schedule          VARCHAR(20) NOT NULL DEFAULT 'EVERY_DAY'
                      CHECK (schedule IN ('EVERY_DAY', 'WEEKDAYS', 'WEEKENDS', 'SPECIAL_DAYS'))
);

CREATE TABLE journey_stop (
    journey_stop_id SERIAL PRIMARY KEY,
    journey_number  INTEGER NOT NULL REFERENCES journey (journey_number) ON DELETE CASCADE,
    station_id      INTEGER NOT NULL REFERENCES station (station_id) ON DELETE RESTRICT,
    stop_order      INTEGER NOT NULL CHECK (stop_order > 0),
    arrival_time    TIME,
    departure_time  TIME,
    CONSTRAINT uq_journey_stop_order UNIQUE (journey_number, stop_order),
    CONSTRAINT uq_journey_stop_station UNIQUE (journey_number, station_id),
    CONSTRAINT ck_journey_stop_has_time CHECK (arrival_time IS NOT NULL OR departure_time IS NOT NULL),
    CONSTRAINT ck_journey_stop_times CHECK (departure_time >= arrival_time)
);

-- An arrival cannot be before the departure from the previous stop
CREATE FUNCTION check_journey_stop_order() RETURNS TRIGGER AS $$
DECLARE
    prev_departure TIME;
    next_arrival   TIME;
BEGIN
    SELECT COALESCE(departure_time, arrival_time) INTO prev_departure
    FROM journey_stop
    WHERE journey_number = NEW.journey_number AND stop_order < NEW.stop_order
    ORDER BY stop_order DESC LIMIT 1;

    SELECT COALESCE(arrival_time, departure_time) INTO next_arrival
    FROM journey_stop
    WHERE journey_number = NEW.journey_number AND stop_order > NEW.stop_order
    ORDER BY stop_order LIMIT 1;

    IF prev_departure IS NOT NULL AND COALESCE(NEW.arrival_time, NEW.departure_time) < prev_departure THEN
        RAISE EXCEPTION 'Arrival before departure from previous stop (%)', prev_departure;
    END IF;
    IF next_arrival IS NOT NULL AND COALESCE(NEW.departure_time, NEW.arrival_time) > next_arrival THEN
        RAISE EXCEPTION 'Departure after arrival at next stop (%)', next_arrival;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journey_stop_order
BEFORE INSERT OR UPDATE ON journey_stop
FOR EACH ROW EXECUTE FUNCTION check_journey_stop_order();

CREATE TABLE reservation (
    reservation_id       SERIAL PRIMARY KEY,
    journey_number       INTEGER NOT NULL REFERENCES journey (journey_number) ON DELETE RESTRICT,
    traveler_id          INTEGER NOT NULL REFERENCES traveler (traveler_id) ON DELETE CASCADE,
    seat_id              INTEGER NOT NULL REFERENCES seat (seat_id) ON DELETE RESTRICT,
    departure_station_id INTEGER NOT NULL REFERENCES station (station_id) ON DELETE RESTRICT,
    arrival_station_id   INTEGER NOT NULL REFERENCES station (station_id) ON DELETE RESTRICT,
    departure_datetime   TIMESTAMP NOT NULL,
    travel_time_minutes  INTEGER NOT NULL CHECK (travel_time_minutes > 0),
    price_cents          INTEGER NOT NULL CHECK (price_cents >= 0),
    reserved_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_reservation_stations CHECK (departure_station_id <> arrival_station_id),
    CONSTRAINT uq_reservation_seat_segment
        UNIQUE (journey_number, seat_id, departure_station_id, arrival_station_id, departure_datetime)
);
