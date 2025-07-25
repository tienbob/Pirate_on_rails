// Entry point for the importmap-rails setup
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import PaymentController from "controllers/payment_controller"
import MovieSearchFormController from "controllers/movie_controller"
import ClientController from "controllers/client"
import ChatController from "controllers/chat_controller"

const application = Application.start()
application.register("payment", PaymentController)
application.register("movie", MovieSearchFormController)
application.register("client", ClientController)
application.register("chat", ChatController)


