// Entry point for the importmap-rails setup
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import PaymentController from "controllers/payment_controller"
import MovieController from "controllers/movie_controller"
import ClientController from "controllers/client"
import ChatController from "controllers/chat_controller"
import SeriesController from "controllers/series_controller"

const application = Application.start()
application.register("payment", PaymentController)
application.register("movie", MovieController)
application.register("client", ClientController)
application.register("chat", ChatController)
application.register("series", SeriesController)


