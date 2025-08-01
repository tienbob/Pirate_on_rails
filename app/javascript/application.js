// Entry point for the importmap-rails setup
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import PaymentController from "controllers/payment_controller"
import MovieController from "controllers/movie_controller"
import ClientController from "controllers/client"
import ChatController from "controllers/chat_controller"
import SeriesController from "controllers/series_controller"
import SeriesFormController from "controllers/series_form_controller"
import FormValidationController from "controllers/form_validation_controller"

const application = Application.start()
application.register("payment", PaymentController)
application.register("movie", MovieController)
application.register("client", ClientController)
application.register("chat", ChatController)
application.register("series", SeriesController)
application.register("series-form", SeriesFormController)
application.register("form-validation", FormValidationController)

// Initialize Action Cable and assign to window.App.cable for global access
import { createConsumer } from "@rails/actioncable";
window.App ||= {};
window.App.cable = createConsumer();

