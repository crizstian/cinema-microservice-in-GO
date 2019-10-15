# Cinema Microservice written in GO

![](../../images/Group5.png)


The architecture of the following `docker-compose.yml` consists of:

- **1 consul server**

  This consul server has a port mapping in the following config `18500:8500` so we can access `consul-ui` from our browser `http://localhost:18500`

- **3 mongodb containers**
  
  The mongodb cluster is configured as a replica set, and is the database for the cinema microservices each service has its own db

- **1 payment-sercice**
  
  The payment service has Stripe configuration, in order to start this container you need to set the following two env variables:

  -- ${STRIPE_SECRET}
  
  -- ${STRIPE_PUBLIC}

- **1 notification-service**

  The notification service has a smtp configuration under the hood, so that when a payment has been successfully the booking service can send the ticket generated through the notification service, in order to start this container there are two env variables to set:

  -- ${EMAIL}

  -- ${EMAIL_PASS}

  smtp service is only configured to accept gmail config

- **1 booking-service**
  
  The booking service is the orchestrator of this architecture, this container is listening through port 8000 and url /booking/ to generate a ticket, then process a payment through the payment service, and once paid, send the ticket via email through the notification service.

## Deploy the architecture using Docker Compose V3

In Order to deploy this architecture, first 4 ENV variables mentioned above, must be setup in your terminal so that docker-compose can read them, then run the `docker-compose.yml` file:

```bash
cinemas-microservices/deploy/docker-compose/service-mesh-connect$ docker-compose up
```

Once the container has been started, please wait until all mongo replicas are synced, once synced all micro services will be running without issues.

## Testing the architecture

There are two ways to test the whole architecture:

#### 1] through `go test` with the following command:
  ```bash
  cinemas-microservices/booking-service/$ go test -v -timeout 30s integration_test -run TestBookingEndpoint -count=1
  ```

The `booking-service` project has an `integration test` config files, the file to test is `http_test` which is the one that is configured to test the booking-service endpoint, which is the frontdoor for this microservices. In order to test it, you can run the command above.


#### 2] through some REST API tool like `postman` 

set the body like the following

```json
{
  "user": {
    "name": "Cristian",
    "lastName": "Ramirez",
    "email": "cristiano.rosetti@gmail.com",
    "creditCard": {
      "number": "4242424242424242",
      "cvc": "123",
      "exp_month": "12",
      "exp_year": "2019"
    },
    "membership": "7777888899990000"
  },
  "booking": {
    "city": "Morelia",
    "cinema": "Plaza Morelia",
    "movie": {
      "title": "Assasins Creed",
      "format": "IMAX"
    },
    "schedule": "1569600200785",
    "cinemaRoom": 7,
    "seats": ["45"],
    "totalAmount": 71
  }
}
```

and set the endpoint to `http://localhost:8000/booking/`