#!/bin/bash
# init-replica.sh - Inicialización simplificada del MongoDB Replica Set
# Para uso con docker-compose local (SIN Consul/Nomad/Vault)

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MongoDB Replica Set - Inicialización Local"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Función para esperar a que un MongoDB esté listo
wait_for_mongo() {
  local host=$1
  local port=$2
  local max_attempts=60
  local attempt=1

  echo "⏳ Esperando MongoDB en $host:$port..."

  while [ $attempt -le $max_attempts ]; do
    if mongosh --host "$host" --port "$port" --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
      echo "✅ MongoDB en $host:$port está listo"
      return 0
    fi

    echo "   Intento $attempt/$max_attempts..."
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "❌ Timeout esperando MongoDB en $host:$port"
  return 1
}

# Función para verificar si el replica set ya está inicializado
is_replica_initialized() {
  local result=$(mongosh --host mongo1 --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
  [ "$result" = "1" ]
}

# Esperar a que los 3 nodos estén listos
echo ""
echo "[1/5] Esperando nodos MongoDB..."
wait_for_mongo mongo1 27017 || exit 1
wait_for_mongo mongo2 27017 || exit 1
wait_for_mongo mongo3 27017 || exit 1

# Verificar si ya está inicializado
echo ""
echo "[2/5] Verificando estado del replica set..."
# if is_replica_initialized; then
#   echo "✅ Replica set ya está inicializado"
#   exit 0
# fi

# Inicializar replica set
echo ""
echo "[3/5] Inicializando replica set..."
mongosh --host mongo1 --quiet --eval "
rs.initiate({
  _id: '${DB_REPLSET_NAME:-rs1}',
  members: [
    { _id: 0, host: 'mongo1:27017' },
    { _id: 1, host: 'mongo2:27017' },
    { _id: 2, host: 'mongo3:27017' }
  ]
})
"

# Esperar a que el replica set se estabilice
echo "⏳ Esperando estabilización del replica set..."
sleep 10

echo "⏳ Esperando a que mongo1 sea PRIMARY..."

max_attempts=60
attempt=1

while [ $attempt -le $max_attempts ]; do
  state=$(mongosh --host mongo1 --quiet --eval "rs.status().members.find(m => m.name.includes('mongo1')).stateStr" 2>/dev/null || echo "")

  if [ "$state" = "PRIMARY" ]; then
    echo "✅ mongo1 es PRIMARY"
    break
  fi

  echo "   mongo1 aún no es PRIMARY (estado actual: '$state'), intento $attempt/$max_attempts..."
  sleep 2
  attempt=$((attempt + 1))
done

if [ "$state" != "PRIMARY" ]; then
  echo "❌ Timeout esperando a que mongo1 sea PRIMARY"
  exit 1
fi


# Crear usuarios administrativos
echo ""
echo "[4/5] Creando usuarios administrativos..."
mongosh --host mongo1 --quiet --eval "
admin = db.getSiblingDB('admin');

// Usuario admin
admin.createUser({
  user: '${DB_ADMIN_USER:-admin}',
  pwd: '${DB_ADMIN_PASS:-adminPassword}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' }
  ]
});

// Usuario para replica set
admin.createUser({
  user: '${DB_REPLICA_ADMIN:-replicaAdmin}',
  pwd: '${DB_REPLICA_ADMIN_PASS:-replicaAdminPassword}',
  roles: [
    { role: 'clusterAdmin', db: 'admin' }
  ]
});

print('✅ Usuarios creados');
"

# Cargar datos de prueba
echo ""
echo "[5/5] Cargando datos de prueba..."
mongosh --host mongo1 -u "${DB_ADMIN_USER:-admin}" -p "${DB_ADMIN_PASS:-adminPassword}" --authenticationDatabase admin --quiet --eval "
use cinemas;

db.movies.drop();

db.movies.insertMany([
  {
    title: 'The Shawshank Redemption',
    year: 1994,
    rating: 9.3,
    director: 'Frank Darabont',
    genres: ['Drama']
  },
  {
    title: 'The Godfather',
    year: 1972,
    rating: 9.2,
    director: 'Francis Ford Coppola',
    genres: ['Crime', 'Drama']
  },
  {
    title: 'The Dark Knight',
    year: 2008,
    rating: 9.0,
    director: 'Christopher Nolan',
    genres: ['Action', 'Crime', 'Drama']
  },
  {
    title: 'Pulp Fiction',
    year: 1994,
    rating: 8.9,
    director: 'Quentin Tarantino',
    genres: ['Crime', 'Drama']
  },
  {
    title: 'Inception',
    year: 2010,
    rating: 8.8,
    director: 'Christopher Nolan',
    genres: ['Action', 'Sci-Fi', 'Thriller']
  }
]);

print('✅ ' + db.movies.countDocuments() + ' películas cargadas');
"

mongosh --host mongo1 -u "${DB_ADMIN_USER:-admin}" -p "${DB_ADMIN_PASS:-adminPassword}" --authenticationDatabase admin --quiet --eval "
use cinemas;

db.movies.find().all();
"

# Verificar estado final
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verificando estado final..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mongosh --host mongo1 -u "${DB_REPLICA_ADMIN:-replicaAdmin}" -p "${DB_REPLICA_ADMIN_PASS:-replicaAdminPassword}" --authenticationDatabase admin --quiet --eval "
var status = rs.status();
print('Replica Set: ' + status.set);
print('');
status.members.forEach(function(member) {
  print('  ' + member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
});
"

echo ""
echo "✅ Replica set inicializado correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
