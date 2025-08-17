k8s_yaml([
    './k8s/postgres.yaml'
])

k8s_resource(
    'db',
    objects=["db-pvc"],
    port_forwards=['5432:5432', '5050:80'],
    links=['http://localhost:5050/']
)

local_resource(
    "init_db",
    "PGPASSWORD=password psql -U user -d postgres -h localhost -p 5432 -f ./fhir/ddl/fhir_database.sql",
    trigger_mode=TRIGGER_MODE_MANUAL,
    resource_deps=['db']
)

local_resource(
    "seed_db",
    "source .venv/bin/activate && pip3 install -r requirements.txt && python3 main.py",
    trigger_mode=TRIGGER_MODE_MANUAL,
    resource_deps=['init_db']
)