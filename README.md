# Demo Database Generator

🌐 English | [Русский](README-ru.md)

## Purpose

The demo database generator program allows you to create a database with the [demo database](https://postgrespro.com/education/demodb) structure and adapt its content to your needs. Thanks to some parameters, you can change the data characteristics, for example, route network or airline fleet.

The program can also be used as a load generator. For example, to demonstrate monitoring systems or to practice query optimization.

## Installation

1. Clone the `demodb` repository.
2. In `psql`, connect to any database, except for `demo`.
    >  **Warning**
    >
    >  If the `demo` database already exists, it will be deleted and all of its data will be lost during the installation.
3. Make sure that you are in the `demodb` repository directory:

   ```sql
   \! pwd
   ```
   If necessary, change the directory, using `\cd`.

4. Start installation:

   ```sql
   \i install.sql
   ```

The commands create the `demo` database and two schemas in it:
   * `gen` — for the generator objects
   * `bookings` — for the created demo database objects

To work with the generator, you need the following extensions:
   * `btree_gist` — to implement a temporary key
   * `earthdistance` and `cube` — to calculate the great circle distance
   * `dblink` — to launch parallel processes
   
As a rule, these extensions are included in the standard PostgreSQL installation package.

## Quick Start

### Launch Generation

The demo database generation is always performed by parallel processes (even if there is only one process).

To launch generation, run the `generate` procedure, specifying the start and end simulation time.

For example, to generate a database for a one-year period, run the following command:

```sql
CALL generate( now(), now() + interval '1 year' );
```

To speed up generation, you can run several parallel processes:

```sql
CALL generate( now(), now() + interval '1 year', 4 );
```

### Check generation status

To quickly check the generation status, run the following command:

```sql
SELECT busy();
```

Possible values:

  * `t` (true) — generation is in process
  * `f` (false) — generation is completed

To get more details, see the `gen.log` generator log:

```sql
SELECT * FROM gen.log ORDER BY at DESC LIMIT 30 \watch 60
```

### Abort generation

To abort generation, run the following command:

```sql
CALL abort();
```

> **Note**
>
> A broken connection does not cancel generation.

### Complete generation

1. To make sure that generation is complete, check its status:

   ```sql
   SELECT busy();
   ```

   If generation is completed successfully, the output will be `f` (false).

2. Check the created demo database:

   ```sql
   \i check.sql
   ```

### Export database

You can export the demo database as an SQL script.

To create an SQL script, in the repository directory, run the following command as an OS user:

```sh
./export.sh > `date +%Y%m%d`.sql
```

### Continue generation

You can continue generation from where it stopped.

For example, to generate data for another three months, run the following command:

```sql
CALL continue( now() + interval '1 year 3 month', 4 );
```

## Setup

To customize data generation, change the required configuration parameters at the database level:

```sql
ALTER DATABASE demo SET parameter-name = value;
```

> **Note**
>
> You cannot change configuration parameters at the session level (`SET`) since parallel processes require access to their values.

Some internal settings are not available at the user level: they are implemented as immutable functions or constants in the source code (incorrect values can lead to generation errors or unexpected results).

The available configuration parameters are described below.

### `gen.connstr`

Connection string to the `demo` database.

Default value: `dbname=demo` (connection to a local server). If necessary, you can specify any value for this parameter supported by libpq.

### `gen.airlines_name`

Airline name. Returned only as part of the `bookings.version` function output.

Default value: `PostgresPro`.

### `gen.airlines_code`

Airline code. Used as a prefix to a ticket number (`bookings.tickets.ticket_no`).

Default value: `PG`.

### `gen.traffic_coeff`

Factor for converting relative passenger traffic (`gen.airports_data.traffic`) into a number of bookings made from an airport within a week.

### `gen.domestic_frac`

Fraction of flights with flight segments within one country. This is a target value. Used to build a flight graph.

Default value: `0.9`.

### `gen.roundtrip_frac`

Fraction of round trip bookings. This is a target value. The real number is less than the target since return tickets are not always available.

Default value: `0.9`.

### `gen.delay_frac`

Fraction of delayed flights.

Default value: `0.05`.

### `gen.cancel_frac`

Fraction of cancelled flights.

Default value: `0.005`.

### `gen.exchange`

Factor for converting the flight duration (in minutes) into the ticket price in the chosen currency. Depending on the travel class, an additional multiplying factor is applied (`get_price` function).

Default value: `50`.

### `gen.max_pass_per_booking`

Maximum number of passengers per booking.

Default value: `5`.

### `gen.min_transfer`

Minimum time in hours between connecting flights.

Default value: `2`.

> **Note**
>
> The lower the limit is, the more flights become available for route planning. At the same time, the risk of getting late for a connecting flight is growing.

### `gen.max_transfer`

Maximum time in hours between connecting flights.

Default value: `48`.

> **Note**
>
> The higher the limit is, the higher the chances are that the passenger will get to their destination by our airline.

### `gen.max_hops`

Maximum number of flight connections in one ticket.

Default value: `4`.

> **Note**
>
> The higher the limit is, the higher the chances are that the flight is chosen for a certain route.

### `gen.log_severity`

Priority of messages to be logged in the `gen.log` log table. The highest priority is `0`.

Default value: `0` (only important messages are logged). It it recommended to change the default value only for debugging purposes.

### `bookings.lang`

Language in which names of aircraft models, countries, cities, and airports are displayed. The parameter is set during the database deployment. The Russian (`ru`) and English (`en`) languages are available.

Default value: `en`.

## Software Interface

Procedures and functions that allow users to work with the generator.

### `generate`

Launch demo database generation.

Parameters:

  * `start_date` (`timestamptz`) — simulation start time for generation
  * `end_date` (`timestamptz`) — simulation end time for generation
  * `jobs` (`integer`) — number of parallel processes (default value: `1`)

Example:

```sql
CALL generate(
    start_date => date_trunc( 'day', now() ),
    end_date   => date_trunc( 'day', now() + interval '1 year' ),
    jobs       => 4
);
```

### `continue`

Continue demo database generation from where it stopped after the previous `generate` or `continue` call.

Parameters:

  * `end_date` (`timestamptz`) — simulation end time for generation
  * `jobs` (`integer`) — number of parallel processes (default value: `1`)

The simulation start time is set automatically. It corresponds to the end of the previous generation process.

Example:

```sql
CALL continue(
    end_date   => date_trunc( 'day', now() + interval '2 years' ),
    jobs       => 4
);
```

### `busy`

Show the current generation status.

Possible values:

  * `t` (true) — generation is in progress
  * `f` (false) — generation is completed

Example:

```sql
SELECT busy();
```

### `abort`

Cancel generation before it is completed.

Example:

```sql
CALL abort();
```

After generation is aborted, you can launch a new generation process using `generate`. It is not recommended to resume generation using `continue` since it does not guarantee correct generation.

### `get_passenger_name`

Return a random passenger`s name from a chosen country.

Parameter:

  * `country` (`text`) — country code

Possible default values: `RU` (Russia), `CN` (China), `IN` (India), `US` (the USA), `CA` (Canada), `JP` (Japan), `FR` (France), `DE` (Germany), `IT` (Italy), `GB` (the UK), `CL` (Chile), `SE` (Sweden), `NP` (Nepal), `FI` (Finland), `NZ` (New Zealand), `AT` (Austria), and `CZ` (the Czech Republic).

Example that returns ten random Nepalese names:

```sql
CALL calc_names_cume_dist(); -- execute once
SELECT get_passenger_name('NP') FROM generate_series(1,10);
```

> **Note**
>
> * To add a new country, add new names to the `firstnames.dat` and `lastnames.dat` reference files (for more information, refer to the [«Questions and Answers»](#how-can-I-add-a-new-country) section).
> * The function is not necessary to work with the demo database but can be useful for other databases that require random reasonably distributed names.

## Log Table

The generator logs messages in the `gen.log` table that you can check after generation or use to monitor the generation process:

```sql
SELECT * FROM gen.log ORDER BY at DESC LIMIT 30 \watch 60
```

The log table stores all the messages with the priority equal to or higher than the `gen.severity` parameter value. By default, only important messages with the `0` priority are logged. For debugging, you can set a non-zero value for the parameter.

Key messages and their meaning are listed below:

* Job _N_ (connname=_connection_): _result_

   Work process _N_ is launched using _connection_.

* _day_: one day in _time_

   _time_ real time was required to calculate _day_ simulation day. Displayed once in a simulation day.

* New bookings: _B_ (forceoneway _F_), nopath _P_, noseat _S_

   During the simulation day, _B_ bookings were created. _F_ of them were planned as round-trip (considering the `gen.roundtrip_frac` target parameter) but remained one-way since a return ticket was not available. _P_ booking attempts failed since there were no suitable flights, and _S_ attempts failed since there were no free seats for one of the chosen flights.
   
* Book-ref retries = _R_ (_F_ retries/booking)

   During the simulation day, it took _R_ retries to generate a random booking reference due to unavailability of initially chosen values. The _F_ value is a number of retries per booking.

   >  **Note**
   >
   >  The longer the generator works, the less numbers are available and the more time is needed to find a free one. In total, there are about 2 billion booking numbers. With its default configuration, the generator uses about 5 million numbers in one simulation year. For this reason, no slow-downs should be expected in several simulation years.

* New boarding passes: _BP_

   During the simulation day, _BP_ boarding passes were created.

* Building routes, range _period_

   Routes with a _period_ validity period were built. The list of new routes follows.

* _А1_ -> _A2_: _model_ x _N_, traffic = _P_ pass/week

   The route from the _А1_ airport to the _А2_ airport is built. The route is flown by the _model_ _N_ aircraft once a week. The expected passenger traffic is _P_ passengers a week.

* Cannot choose an aircraft for _А1_ -> _А2_ (out of range?)

   The route from the _А1_ airport to the _А2_ airport cannot be built. As a rule, the reason for this is that the distance between the airports cannot be covered by any aircraft of an airline fleet. It is a warning, not an error, but if it repeats, you should change the fleet.

* Vacuum

   Vacuuming and analysis.

* End date reached, exiting

   Work process is completed.

## Check Script

After the demo database is generated, some standard checks are recommended to ensure quality of the generated data.

```sql
\i check.sql
```

The script executes several queries. The query results are described below.

### Generation errors in log

Number of errors that occur during generation. The error messages are logged in the `gen.log` log table and start with the word _Error_.

### Generation stats

Number of generated bookings (`num_bookings`), tickets (`num_tickets`), flight segments (`num_segments`), flights (`num_flights`), and routes (`num_routes`).

### Generation speed

Generation speed: number of processed events per second. The calculation includes idle time between the `generate` and `continue` calls.

### Airplanes utilization

The first query (`avg_fill_ratio`) returns average flight occupancy.

The second query shows the number of flights without passengers. A small value is usually acceptable.

The third query returns the list of aircraft models with the number of routes each model operated.

> **Note**
>
> * Do not add the values returned by the above queries since various models can perform one and the same route at various time.
> * The `NOT USED` verdict is displayed when a model was not used for any of the flights. It is recommended to replace it.
> * The `WRONGLY USED` verdict is a sign of an algorithm error.

### Roundtrips to overall tickets

Ratio of round-trip tickets to the total number of tickets (`roundtrip_frac`) and target value (`target_frac`) set by the `gen.roundtrip_frac` parameter. The real number is less than the target since return tickets are not always available.

### Passengers per booking

The first query checks that there are not more passengers in a booking than the `gen.max_pass_per_booking` parameter value. The `ERROR: max_pass_per_bookings not satisfied` verdict is displayed when the requirement is violated and is a sign of an algorithm error.

The second query groups bookings by the number of passengers. For example, `npass` being 2 and `cnt` being 100 mean that 100 bookings include two passengers.

### Frequent flyers

The query groups the passengers by the number of bookings they made. For example, `nbook` being 3 and `cnt_pass` being 1000 mean that 1000 passengers made 3 bookings.

### Segments per ticket

The query groups the tickets by the number of flight segments. For example, `segments` being 3 and `cnt` being 1000 mean that 1000 tickets contain three flight segments.

### Flight statuses

Number of flights in various statuses.

> **Note**
>
> There are three statuses that do not depend on the database size and always have a few flights — `On Time`, `Departed`, and `Boarding`. If there are no flights in these statuses, continue generation for a few simulation hours to ensure data variety.

### Flight durations

If the first query returns the `ERROR: route and flight discrepancy` verdict, data in the `bookings.routes` and `bookings.flights` tables are desynchronized. This is a sign of an algorithm error.

The second query displays the minimum (`min_..._duration`), average (`avg_..._duration`), and maximum (`max_..._duration`) flight duration — both scheduled (`..._sch_...`) and actual (`..._act_...`).

### Flight delays

Minimum (`min_..._delay`), average (`avg_..._delay`), and maximum (`max_..._delay`) delay of departures (`..._dep_...`) and arrivals (`..._arr_...`).

### Overbookings

Number of overbookings.

The `ERROR: overbooking` verdict is displayed when there are more boarding passes issued than the seats and is a sign of an algorithm error.

### Cancelled flights fraction

Fraction of cancelled flights (`actual_cancelled_frac`) and target value (`target_cancelled_frac`) set by the `gen.cancel_frac` parameter. These values must match with high level of precision.

### Adjacency of segments

The `ERROR: non-adjacent segments` verdict is displayed when there are several flight segments in one ticket and the airport of arrival and the airport of departure do not match. This is a sign of an algorithm error.

### Routes validity ranges

The `ERROR: validity ranges have holes` verdict notifies that there are gaps between the route validity ranges. This is a sign of an algorithm error.

### Flights consistency with routes

The `ERROR: absent flights` verdict is displayed when the `bookings.flights` table does not contain flights that it should have according to the `bookings.routes` table.

The `ERROR: excess flights` verdict shows that the `bookings.flights` table contains flights that are not specified in the `bookings.routes` table.

Two verdicts (`absent and excess flights`) can be displayed at once. Any of these verdicts is a sign of an algorithm error.

### Timings

The `ERROR: flights timing discrepancy` verdict in the first query notifies about time desynchronization in the flight information.

The `ERROR: boarding after takeoff` verdict is displayed in the second query if boarding of passengers continues after the aircraft departure.

The `ERROR: booking after boarding` verdict is displayed in the third query when booking continues after boarding starts.

Any of these verdicts is a sign of an algorithm error.

### Miss the flight

A passenger can miss their flight due to delay of their connecting flight. The generator needs to ensure that the passenger does not board the next flight.

The first query returns the actual number of passengers who are late for their connecting flight, as well as the number of incorrectly registered missing flights and number of unregistered missing flight. The `ERROR: incorrect missed flights` verdict is a sign of an algorithm error.

The `ERROR: boarding after miss` verdict is displayed in the second query when a passenger boards the flight after missing it. This is a sign of an algorithm error.

### Interlaced flights

The `ERROR: interlaced flights` verdict is displayed when a passenger makes more than one flight at the same time. This is a sign of an algorithm error.

## Demo Database Export

The generated demo database can be exported as a `pg_dump`-like SQL script.

To export the demo database, in the repository directory, run the following script as an OS user:

```sh
./export.sh | gzip > `date +%Y%m%d`.sql.gz
```

The script accepts the same connection parameters as `pg_dump`.

The exported SQL script will contain the objects from the `booking` schema, including the definitions of the `bookings.now` (end simulation time set during generation) and `bookings.version` (version of the generated demo database) functions, as well as commands to set the `bookings.lang` and `search_path` parameters at the database level.

## Internals

The generator imitates the airline work. It creates and processes random events — passengers’ booking of tickets, checking-in and boarding, departure and arrival of aircrafts etc. The event handler can add new events to the queue implementing finite state automation of the flight statuses.

The demo database has two schemas:
 
   * `gen` — with service tables used during generation and storing its current state
   * `bookings` — with tables of the created demo database that are described in the [demo database documentation](https://postgrespro.com/education/demodb)

The `gen` tables are described below.

### `gen.events`

Table with events in queue.

The event queue is handled by the `process_queue` procedure, while separate events — by the `process_event` procedure.

Types of events are listed below.

#### INIT

Event that flags initiation of the process. Handled by the `do_init` procedure that initiates states of all tables and adds the initial set of events: `BUILD ROUTES`, `BOOKING`, `VACUUM`, and `MONITORING`.

#### BUILD ROUTES

Route rebuild event. Handled by the `build_routes` procedure that creates a random but connected graph.

The first `BUILD ROUTES` event is added as a result of the `INIT` processing. A one-month schedule, starting from the start generation date, is created. After the first `BUILD ROUTES` event is processed, a new one is added to the event queue, so that the routes are then rebuilt every month. Each route also gets the `FLIGHT` event, setting the start of booking for this route a month before it becomes valid.

##### How is a route graph built?

The graph is built according to the steps below:

1. Airports with a non-empty `traffic` column of the `gen.airports_data` table are found.
2. Two edges (flights) are randomly added from each airport to two other airports following the below rules:

   * The least busy airport is the first to be added edges from.
   * There are no flights segments between the airports located in one city.
   * Airport choice depends on the airport traffic and is reversely proportionate to the distance between the airports.
   * If there are at least two airports in a country, the odds of choosing an airport in the same country are determined by the `gen.domestic_frac` parameter.

3. The graph edges are added to the `gen.directions` table.
4. Edges are added till connectivity is achieved. It is ensured by the `gen.directions_connect` table.
5. New routes are transferred from the `gen.directions` table to the `bookings.routes` table at a specified `validity` period.
6. An aircraft for the route and the number of flights per week are determined based on the expected traffic between the airports (specified in the `gen.week_traffic` table).

#### BOOKING

Booking event for a particular airport. Handled by the `make_booking` procedure that books a flight to a random airport.

The next `BOOKING` event for the source airport is created so that the events constituted the Poisson process with the frequency corresponding to the passenger traffic of the airport.

To calculate the average number of booking events per week, multiply the `airports_data.traffic` and `gen.traffic_coeff` parameter values.

##### How is booking done?

Booking is done in the following steps:

1. An airport of arrival is chosen according to the following rules:

   * Airport choice depends on the airport traffic and is reversely proportionate to the distance between the airports.
   * If there are at least two airports in a country, the odds of choosing an airport in the same country are determined by the `gen.domestic_frac` parameter.

2. The route to the airport (`get_path` function) is chosen according to the following rules:
   
   * The route has the fewest flight segments that do not exceed the `gen.max_hops` parameter value.
   * There are available tickets for the flight.
   * There is enough time before departure: checking-in has not started yet.
   * There are at least `gen.min_transfer` hours (to avoid missing the connecting flight in case the previous one is delayed) and not more than `gen.max_transfer` hours (to avoid long waiting) between the connecting flights.
   * The route has the soonest first connecting flight.
   
3. Number of passengers in a booking is chosen randomly depending on the `gen.max_pass_per_booking` parameter.
4. Booking results in:

   * A new row in the `bookings.bookings` table
   * New rows for each ticket in the `bookings.tickets` table (one for each passenger and flight direction)
   * New rows in the `bookings.segments` table


    >   **Note**
    >
    >   If there is no suitable route or if tickets cannot be booked for all the passengers, the booking attempt is considered failed and cancelled.

5. With the `gen.roundtrip_frac` probability, booking of a return ticket is attempted in a random period of time (up to a month; usually — about a week).

    >   **Note**
    >
    >   * The return route can differ from the source route.
    >   * A failed attempt to book a return flight does not cancel the outbound flight.

#### FLIGHT

Event of adding a flight to the schedule a month before the departure. Handled by the `open_booking` procedure that adds a row to the `bookings.flights` table for the flight enabling booking (`Scheduled` status).

With the `gen.cancel_frac` probability, the flight is cancelled (`Cancelled` status). This happens in advance and never when any ticket is bought.

If the flight is not cancelled, the day before the departure, registration for this flight starts. The `REGISTRATION` event is added.

#### REGISTRATION

Registration event a day before the departure. Handled by the `registration` procedure that changes the flight status to `On Time` and sets the actual start registration time (a few-minute delay is acceptable).

With the `gen.delay_frac` probability, the flight is delayed (`Delayed` status) for the period of one to 12 hours.

The `CHECK-IN` event is created for each ticket sold for the flight (checking-in is closed 40 minutes before the departure). Then, the `BOARDING` event is created for the flight.

#### CHECK-IN

Event of checking in for the flight for a particular ticket. Handled by the `check_in` procedure that creates rows in the `bookings.boarding_passes` table for boarding passes for each flight segment of the ticket (all of the flights within a ticket are considered connecting).

> **Note**
>
> A passenger has to check in only once for the first flight segment of the ticket.

#### BOARDING

Boarding event half an hour before the departure. Handled by the `boarding` procedure that changes the flight status to `Boarding`.

The `GET IN` event is added for each ticket sold for this flight. Boarding lasts for 20 minutes. If the boarding finishes before the generation is completed, the `GET IN` events are not created and the number and time of boarding are entered into the boarding pass (`bookings.boarding_passes` table) straight away. This optimization significantly reduces the number of created events and speeds up generation.

The `TAKEOFF` event is also created to set the actual departure time (a few-minute delay is acceptable).

#### GET IN

Event of getting in the aircraft for a particular ticket. Handled by the `get_in` procedure that enters the boarding number and time into the boarding pass (`bookings.boarding_passes` table).

#### TAKEOFF

Take-off event. Handled by the `takeoff` procedure that changes the flight status to `Departed` and creates the `LANDING` event determining the actual flight duration (the actual duration can differ from the schedule by few percents).

#### LANDING

Landing event. Handled by the `landing` procedure that changes the flight status to `Arrived`. After that, the flight is considered completed; new events are not generated.

#### VACUUM

Vacuuming event. Handled by the `vacuum` procedure.

The queue is processed by different transactions but within a single `CALL` operator. For this reason, the statistics collector does not receive the table statistics: autovacuum does not know that tables have been changed and is not triggered.

That is why, vacuuming and analysis are forced through the `vacuum` procedure once a simulation week. It is launched in a separate process with the `dblink` extension.

#### MONITORING

Monitoring event. Handled by the `monitoring` procedure that adds information about the previous day to the `gen.log` log table.

### `gen.events_history`

Table storing processed events from the `gen.events` table for debugging.

### `gen.airplanes_data`

Table with aircraft model data. All the rows and columns are transferred to the `bookings.airplanes_data` table, except for the `in_use` column that determines whether the model will be used for flights.

### `gen.seats`

Table with cabin configuration data. All the data are transferred to the `bookings.seats` table without changes.

### `gen.seats_remain`

Table used by the generator to monitor the remaining free seats for flights.

### `gen.airports_data`

Table with airport data. All the rows and columns are transferred to the `bookings.airports_data` table, except for the following columns:

   * `country_code` — two-character country code compliant with ISO 3166-1 alpha-2 (part of the `bookings.tickets.ticket_no` ticket number)
   * `traffic` — relative passenger traffic of an airline for a particular airport (to calculate the absolute number of booking attempts in a week, multiply the `traffic` value by the `gen.traffic_coeff` parameter valuer)

### `gen.directions`

Table with airport pairs connected with direct flights. Used by the generator to build the flight graph.

### `gen.directions_connect`

Table used to ensure connectivity of flight graph.

### `gen.airports_to_prob`

Table storing pre-calculated cumulative probabilities of flights from one airport to another (not necessarily connected with a direct flight) and used to build the flight graph and choose an airport for booking.

### `gen.week_traffic`

Table with the forecast of passenger traffic between two airports connected with a direct flight.

### `gen.firstnames`

Table with names sorted by countries with their usage frequency. The table allows to group names using the `grp` column, for example, masculine and feminine names for the languages where a family name form depends on the gender. During initialization, the `cume_dist` column receives cumulative probability of choosing a particular name.

### `gen.lastnames`

Table with family names sorted by countries with their usage frequency. The table allows to group family names using the `grp` column. During initialization, the `cume_dist` column receives cumulative probability of choosing a particular family name.

### `gen.passengers`

Table listing unique passengers. Used by the generator to ensure that one `passenger_id` document number corresponds to one name and that one passenger does not participate in several trips at the same time. The information from this table is not transferred to the demo database where there is no “passenger” entity.

### `gen.missed_flights`

Table used by the generator to track tickets of the passengers who missed their connecting flight due to the previous flight delay.

### `gen.stat_bookings`

Booking statistics. Used for monitoring.

### `gen.stat_jobs`

Parallel process statistics. Normally, counts of processed events are almost equal. If generation does not increase count of a certain process, look for an error message in the `gen.log` table.

### `gen.stat_bookrefs`

Statistics on retries required to generate the unique `book_ref` number.


## Answers and Questions

### How can I add a new language?

The language is set by the `bookings.lang` parameter. Aircraft model names (`airplanes` view) as well as names of airports, cities, and countries (`airports` view) are translated into this language. Initially, translations to two languages are available: Russian (`ru`) and English (`en`).

To add a new language, provide translations of the relevant names into this language for the `airport_name`, `city`, and `country` JSON-columns of the `gen.airports_data` table and the `model` column of the `gen.airplanes_data` table.

This is a challenging task since the table with airports contains about 5500 lines. You need to translate at least the rows with a non-null `traffic` value that will be used to build a route network.

### How can I change an airline fleet?

To change an airline fleet, add new aircraft models and cabin configurations to the `gen.airplanes_data` and `gen.seats` tables. These data will be transferred to the relevant `bookings` tables. Only the aircrafts with the `in_use` attribute will be used to build routes.

> **Note**
>
> * Flying distance of the aircrafts should cover the distance between the cities. Otherwise, flights would not be possible.
> * Seat capacity should cover the expected passenger traffic: flights are performed at least once a week, maximum - 7 days a week. If a fleet does not offer enough variety of seats, flights may end up overcrowded or underfilled.

### How were the countries for the demo database chosen?

The list of demo database countries includes the countries native to PostgreSQL major contributors and some other countries related to PostgreSQL development.

For more information about adding new countries to the list, refer to the subsection [below](#how-can-I-add-a-new-country).

### How many airports were chosen for each country?

To calculate the number of airports for a country, add country square logarithm and country population logarithm and square this sum:

$$ 0,5 ( log( country square, km^2 ) + log( country population, mln ) - 5 )^2 $$

For more information about adding new airports, refer to the subsection [below](#how-can-I-add-a-new-airport).

### How can I change the route network within countries and cities?

You can include airports to the route network. To do this, set a non-null `traffic` value for the required airports in the `gen.airports_data` table.

### How can I add a new country?

To add a new country, you need not only to specify the airports in the `gen.airports_data` table but also to update to the `firstnames.dat` and `lastnames.dat` reference files through the `gen.firstnames` and `gen.lastnames` tables.

To do this, you will need the following data:

   * `country` — two-character country code compliant with ISO 3166-1 alpha-2
   * `grp` — `-` or criterion to group names/family names

     You can use any text value as long as it is the same for the `gen.firstnames` and `gen.lastnames` tables (for example, `m` and `f`).

     For languages where family name forms depend on gender (for example, Slavic and Baltic languages, such as Russian) you need to divide all the names into masculine and feminine. Names that can be both masculine and feminine should be put into both groups (their usage frequency can differ).
   
     The same principle applies to distribute names into other groups. For example, to create ethnical groups with various systems of names.
   
   * `name` — name/family name in Latin characters
   * `qty` — integer that reflects the name/family name usage frequency

     For example, number of people registered with this name/family name.

Currently, the reference files contain names in Latin characters for the following countries: Russia (`RU`), China (`CN`), India (`IN`), the USA (`US`), Canada (`CA`), Japan (`JP`), France (`FR`), Germany (`DE`), Italy (`IT`), the UK (`GB`), Chile (`CL`), Sweden (`SE`), Nepal (`NP`), Finland (`FI`), New Zealand (`NZ`), Austria (`AT`), and the Czech Republic (`CZ`).

Once the tables are updated, to check the result, run the following query where `XX` is a country code:

```sql
CALL calc_names_cume_dist(); -- calculation of cumulative probability
SELECT get_passenger_name('XX') FROM generate_series(1,10);
```

To generate passengers` full names, a family name is randomly chosen from all the groups, then a name from the same group as the family name. There can be no identical full names.

### How can I add a new airport?

To add a new airport, add a new row to the `gen.airports_data` table with the following data:

   * International Air Transport Association (IATA) airport code (`airport_code`)
   * Airport name in all demo database languages (`airport_name`)
   * City name in all demo database languages (`city`)
   * Country name in all demo database languages (`country`)
   * Country code (`country_code`)
   * Timezone (`timezone`)
   * Airport coordinates (latitude and longitude) (`coordinates`)

There is no full, actual, and free database of airports. There are several open-source projects, like [OpenFlights](https://openflights.org/data.php), [OurAirports](https://ourairports.com/data/), and [DataHub](https://datahub.io/core/airport-codes). However, their data integrity and accuracy are not guaranteed.

To get data of a particular airport, use the [IATA official website](https://www.iata.org/en/publications/directories/code-search/).

To ensure data consistency in the `gen.airports_data` table, note the following rules:

* The`city` value is the city that a particular airport serves. As a rule, this is the closest large city, not necessarily the one where the airport is located. For example, the Russian IAR “Golden Ring Yaroslavl International Airport” is located in Tunoshna village, Yaroslavl Region, but the city it serves is the administrative center - Yaroslavl.
* An official airport name usually includes airport location, name of the person it is named after, and some other parts. To contract an airport name:
   * Remove city names (expect when the airport name contains only the city name; for example, AAC “El Arish”).
   * If the name consists of both the location and dedication to somebody, remove the person`s name. For example, SVO “Alexander S. Pushkin Sheremetyevo International Airport” is contracted to “Sheremetyevo”.
   * Omit titles and military ranks. For example, YAI “General Bernardo O’Higgins” turns into “Bernardo O’Higgins”.
   * Avoid such words as “international”, “regional” etc. For example, ROA “Roanoke–Blacksburg Regional” becomes “Blacksburg” (Roanoke is a city name and is also removed).
   * Remove initials from the airport names in Russian. For example, JFK “John F. Kennedy” is shortened to “John Kennedy”.

