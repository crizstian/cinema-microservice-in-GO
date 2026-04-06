# ⚡ Solución Rápida - Error de Hostnames en MongoDB

## 🔴 El Problema

Tus tests fallan con este error:

```
Error: dial tcp: lookup mongo1 on 127.0.0.11:53: no such host
```

**Causa**: El replica set de MongoDB usa hostnames (`mongo1`, `mongo2`, `mongo3`) que no pueden ser resueltos desde fuera de Docker.

---

## ✅ Solución Inmediata (Elige UNA)

### 🚀 OPCIÓN A: Configurar /etc/hosts (MÁS RÁPIDA - 30 segundos)

```bash
# Ejecutar como root
sudo ./platform/scripts/setup-mongodb-hosts.sh 192.168.68.104
```

**Resultado**: Agrega entradas a `/etc/hosts` para resolver `mongo1/2/3` → `192.168.68.104`

**Verificar**:
```bash
ping -c 1 mongo1  # Debería responder desde 192.168.68.104
```

---

### 🔧 OPCIÓN B: Reconfigurar Replica Set (PERMANENTE - 2 minutos)

```bash
# Ejecutar dentro del contenedor
./platform/deploy/docker-compose/scripts/reconfigure-replica-with-ips.sh
```

**Resultado**: MongoDB usará IPs (`192.168.68.104:27017/18/19`) en lugar de hostnames.

**Verificar**:
```bash
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "rs.conf().members"
```

Deberías ver IPs en lugar de `mongo1/2/3`.

---

## ✅ Verificar que Funcionó

Después de aplicar **CUALQUIERA** de las soluciones:

```bash
# Test rápido (30 segundos)
./platform/scripts/test-mongodb-connection.sh -q

# Resultado esperado:
# ✓ Movie tests PASSED
# ✓ Booking tests PASSED
# ✓ Payment tests PASSED
```

---

## 🎯 ¿Cuál Elegir?

| Solución | Ventajas | Cuándo Usar |
|----------|----------|-------------|
| **Opción A** (/etc/hosts) | ⚡ Rapidísimo<br>✅ Sin riesgo | **Desarrollo local**<br>Tests rápidos |
| **Opción B** (Reconfigurar) | 🔒 Permanente<br>🌍 Funciona en todas las máquinas | **Producción**<br>Configuración definitiva |

---

## 📋 Comandos de Verificación

```bash
# 1. Ver configuración actual del replica set
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 \
  --authenticationDatabase admin \
  --eval "rs.conf().members.forEach(m => print(m.host))"

# 2. Ver estado de los miembros
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 \
  --authenticationDatabase admin \
  --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"

# 3. Probar conexión directa
mongosh "mongodb://cristian:cristianPassword2017@192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019/?replicaSet=rs1&authSource=admin"
```

---

## 🆘 Si Nada Funciona

1. **Ver logs de MongoDB**:
```bash
docker logs mongo1 --tail 50
```

2. **Verificar que los puertos estén abiertos**:
```bash
telnet 192.168.68.104 27017
telnet 192.168.68.104 27018
telnet 192.168.68.104 27019
```

3. **Reiniciar MongoDB**:
```bash
cd platform/deploy/docker-compose
docker-compose restart mongo1 mongo2 mongo3
sleep 10
```

4. **Ver documentación completa**:
```bash
cat docs/MONGODB-HOSTNAME-RESOLUTION-FIX.md
```

---

## ⏱️ Tiempo Total Estimado

- **Opción A** (/etc/hosts): ~30 segundos
- **Opción B** (Reconfigurar): ~2 minutos

---

## 🎉 Después de Solucionar

Ejecutar todos los tests:

```bash
./platform/scripts/test-mongodb-connection.sh
```

¡Listo! Tus servicios ahora pueden conectarse correctamente a MongoDB 🚀
