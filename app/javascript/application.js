// Entry point for the importmap-rails setup
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import PaymentController from "controllers/payment_controller"
import MovieSearchFormController from "controllers/movie_search_form"
import ClientController from "controllers/client"

const application = Application.start()
application.register("payment", PaymentController)
application.register("movie-search-form", MovieSearchFormController)
application.register("client", ClientController)


