services {
  id = "mongodb1"
  name = "mongodb1"
  tags = [
    "db"
  ]
  address = "10.7.0.2"
  port = 27017
   checks = [
    {
      id = "mongo",
      name = "mongo TCP on port 27017",
      tcp = "10.7.0.2:27017",
      interval = "10s",
      timeout = "1s"
    }
  ]
}
services {
  id = "mongodb2"
  name = "mongodb2"
  tags = [
    "db"
  ]
  address = "10.7.0.3"
  port = 27017
   checks = [
    {
      id = "mongo",
      name = "mongo TCP on port 27017",
      tcp = "10.7.0.3:27017",
      interval = "10s",
      timeout = "1s"
    }
  ]
}
services {
  id = "mongodb3"
  name = "mongodb3"
  tags = [
    "db"
  ]
  address = "10.7.0.4"
  port = 27017
   checks = [
    {
      id = "mongo",
      name = "mongo TCP on port 27017",
      tcp = "10.7.0.4:27017",
      interval = "10s",
      timeout = "1s"
    }
  ]
}