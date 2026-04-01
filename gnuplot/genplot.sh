# Usage: ./genplot.sh [N]

if [ -z "$1" ]; then
    set -- 0
fi

# 1: low traffic routes
psql -d demo --no-align --tuples-only -c "SELECT string_agg( a_from.coordinates[0] || ' ' || a_from.coordinates[1] || ';' || a_to.coordinates[0] || ' ' || a_to.coordinates[1], ';;' ) FROM routes r JOIN airports a_from ON a_from.airport_code = r.departure_airport JOIN airports a_to ON a_to.airport_code = r.arrival_airport WHERE r.validity = (SELECT DISTINCT validity FROM routes ORDER BY validity OFFSET $1 LIMIT 1) AND cardinality(r.days_of_week) * (SELECT count(*) FROM seats s WHERE s.airplane_code = r.airplane_code) <= 1000" > routes1.dat
/opt/local/bin/gsed -i 's/;/\n/g' routes1.dat
python3 great_circle.py <routes1.dat >routes1_gc.dat

# 2: midddle traffic routes
psql -d demo --no-align --tuples-only -c "SELECT string_agg( a_from.coordinates[0] || ' ' || a_from.coordinates[1] || ';' || a_to.coordinates[0] || ' ' || a_to.coordinates[1], ';;' ) FROM routes r JOIN airports a_from ON a_from.airport_code = r.departure_airport JOIN airports a_to ON a_to.airport_code = r.arrival_airport WHERE r.validity = (SELECT DISTINCT validity FROM routes ORDER BY validity OFFSET $1 LIMIT 1) AND cardinality(r.days_of_week) * (SELECT count(*) FROM seats s WHERE s.airplane_code = r.airplane_code) BETWEEN 1001 AND 2000" > routes2.dat
/opt/local/bin/gsed -i 's/;/\n/g' routes2.dat
python3 great_circle.py <routes2.dat >routes2_gc.dat

# 3: high traffic routes
psql -d demo --no-align --tuples-only -c "SELECT string_agg( a_from.coordinates[0] || ' ' || a_from.coordinates[1] || ';' || a_to.coordinates[0] || ' ' || a_to.coordinates[1], ';;' ) FROM routes r JOIN airports a_from ON a_from.airport_code = r.departure_airport JOIN airports a_to ON a_to.airport_code = r.arrival_airport WHERE r.validity = (SELECT DISTINCT validity FROM routes ORDER BY validity OFFSET $1 LIMIT 1) AND cardinality(r.days_of_week) * (SELECT count(*) FROM seats s WHERE s.airplane_code = r.airplane_code) > 2000" > routes3.dat
/opt/local/bin/gsed -i 's/;/\n/g' routes3.dat
python3 great_circle.py <routes3.dat >routes3_gc.dat

# all airports
psql -d demo --no-align --tuples-only -c "SELECT string_agg( a.coordinates[0] || ' ' || a.coordinates[1], ';' ) FROM airports a" > all_airports.dat
/opt/local/bin/gsed -i 's/;/\n/g' all_airports.dat

# airports on routes
psql -d demo --no-align --tuples-only -c "SELECT string_agg( a.coordinates[0] || ' ' || a.coordinates[1], ';' ) FROM airports a JOIN routes r ON a.airport_code = r.departure_airport WHERE r.validity = (SELECT DISTINCT validity FROM routes ORDER BY validity OFFSET $1 LIMIT 1)" > airports.dat
/opt/local/bin/gsed -i 's/;/\n/g' airports.dat

# generate image
gnuplot routes.gnu > routes.svg

