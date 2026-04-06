#!/bin/bash
# init-replica-with-ips.sh - Inicialización del MongoDB Replica Set con IPs
# Para uso con docker-compose local usando IPs en lugar de hostnames

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  MongoDB Replica Set - Inicialización con IPs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Configuración - Usar IP del host o variable de entorno
MONGO_IP="${MONGO_HOST_IP:-192.168.68.104}"

echo ""
echo -e "${YELLOW}Configuración:${NC}"
echo -e "  IP Base: ${MONGO_IP}"
echo -e "  Replica Set: ${DB_REPLSET_NAME:-rs1}"
echo ""

# Función para esperar a que un MongoDB esté listo
wait_for_mongo() {
  local host=$1
  local port=$2
  local max_attempts=60
  local attempt=1

  echo -e "⏳ Esperando MongoDB en $host:$port..."

  while [ $attempt -le $max_attempts ]; do
    if mongosh --host "$host" --port "$port" --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
      echo -e "${GREEN}✅ MongoDB en $host:$port está listo${NC}"
      return 0
    fi

    echo "   Intento $attempt/$max_attempts..."
    sleep 2
    attempt=$((attempt + 1))
  done

  echo -e "${RED}❌ Timeout esperando MongoDB en $host:$port${NC}"
  return 1
}

# Función para verificar si el replica set ya está inicializado
is_replica_initialized() {
  local result=$(mongosh --host mongo1 --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
  [ "$result" = "1" ]
}

# Esperar a que los 3 nodos estén listos
echo ""
echo -e "${YELLOW}[1/5] Esperando nodos MongoDB...${NC}"
wait_for_mongo mongo1 27017 || exit 1
wait_for_mongo mongo2 27017 || exit 1
wait_for_mongo mongo3 27017 || exit 1

# Verificar si ya está inicializado
echo ""
echo -e "${YELLOW}[2/5] Verificando estado del replica set...${NC}"
if is_replica_initialized; then
  echo -e "${YELLOW}⚠ Replica set ya está inicializado${NC}"
  echo -e "${YELLOW}Reconfigurando con IPs...${NC}"

  mongosh --host mongo1 --quiet --eval "
  var config = rs.conf();
  config.members[0].host = '${MONGO_IP}:27017';
  config.members[1].host = '${MONGO_IP}:27018';
  config.members[2].host = '${MONGO_IP}:27019';
  config.version++;

  try {
    var result = rs.reconfig(config, {force: true});
    print('✅ Replica set reconfigurado');
    printjson(result);
  } catch (e) {
    print('❌ Error al reconfigurar: ' + e);
  }
  "

  sleep 10
  exit 0
fi

# Inicializar replica set con IPs
echo ""
echo -e "${YELLOW}[3/5] Inicializando replica set con IPs...${NC}"
mongosh --host mongo1 --quiet --eval "
rs.initiate({
  _id: '${DB_REPLSET_NAME:-rs1}',
  members: [
    { _id: 0, host: '${MONGO_IP}:27017' },
    { _id: 1, host: '${MONGO_IP}:27018' },
    { _id: 2, host: '${MONGO_IP}:27019' }
  ]
})
"

# Esperar a que el replica set se estabilice
echo -e "⏳ Esperando estabilización del replica set..."
sleep 15

# Crear usuarios administrativos
echo ""
echo -e "${YELLOW}[4/5] Creando usuarios administrativos...${NC}"
mongosh --host mongo1 --quiet --eval "
admin = db.getSiblingDB('admin');

// Usuario admin
try {
  admin.createUser({
    user: '${DB_ADMIN_USER:-admin}',
    pwd: '${DB_ADMIN_PASS:-adminPassword}',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' }
    ]
  });
  print('✅ Usuario admin creado');
} catch (e) {
  if (e.code === 51003) {
    print('⚠ Usuario admin ya existe');
  } else {
    print('❌ Error creando usuario admin: ' + e);
  }
}

// Usuario para replica set
try {
  admin.createUser({
    user: '${DB_REPLICA_ADMIN:-replicaAdmin}',
    pwd: '${DB_REPLICA_ADMIN_PASS:-replicaAdminPassword}',
    roles: [
      { role: 'clusterAdmin', db: 'admin' }
    ]
  });
  print('✅ Usuario replicaAdmin creado');
} catch (e) {
  if (e.code === 51003) {
    print('⚠ Usuario replicaAdmin ya existe');
  } else {
    print('❌ Error creando usuario replicaAdmin: ' + e);
  }
}
"

# Cargar datos de prueba
echo ""
echo -e "${YELLOW}[5/5] Cargando datos de prueba...${NC}"
mongosh --host mongo1 -u "${DB_ADMIN_USER:-admin}" -p "${DB_ADMIN_PASS:-adminPassword}" --authenticationDatabase admin --quiet --eval "
use cinemas;

// Limpiar colección si existe
db.movies.drop();

// Insertar películas de ejemplo
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
" 2>/dev/null || echo -e "${YELLOW}⚠ No se pudieron cargar datos de prueba (probablemente por autenticación)${NC}"

# Verificar estado final
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Verificando estado final...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mongosh --host mongo1 -u "${DB_REPLICA_ADMIN:-replicaAdmin}" -p "${DB_REPLICA_ADMIN_PASS:-replicaAdminPassword}" --authenticationDatabase admin --quiet --eval "
var status = rs.status();
print('Replica Set: ' + status.set);
print('');
print('Miembros:');
status.members.forEach(function(member) {
  print('  ' + member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
});
" 2>/dev/null || mongosh --host mongo1 --quiet --eval "
var status = rs.status();
print('Replica Set: ' + status.set);
print('');
print('Miembros:');
status.members.forEach(function(member) {
  print('  ' + member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
});
"

echo ""
echo -e "${GREEN}✅ Replica set inicializado correctamente${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Cadena de conexión:${NC}"
echo -e "${YELLOW}mongodb://${DB_ADMIN_USER:-admin}:****@${MONGO_IP}:27017,${MONGO_IP}:27018,${MONGO_IP}:27019/?replicaSet=${DB_REPLSET_NAME:-rs1}&authSource=admin${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
