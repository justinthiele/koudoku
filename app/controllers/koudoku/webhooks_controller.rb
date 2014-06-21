module Koudoku
  class WebhooksController < ApplicationController

    def create
      
      raise "API key not configured. For security reasons you must configure this in 'config/koudoku.rb'." unless Koudoku.webhooks_api_key.present?
      raise "Invalid API key. Be sure the webhooks URL Stripe is configured with includes ?api_key= and the correct key." unless params[:api_key] == Koudoku.webhooks_api_key
    
      data_json = JSON.parse request.body.read
    
      if data_json['type'] == "invoice.payment_succeeded"
        stripe_id = data_json['data']['object']['customer']
        amount = data_json['data']['object']['total'].to_f / 100.0
        subscription = ::Subscription.find_by_stripe_id(stripe_id)
        subscription.payment_succeeded(amount)

      elsif data_json['type'] == "charge.failed"
        stripe_id = data_json['data']['object']['customer']
        subscription = ::Subscription.find_by_stripe_id(stripe_id)
        subscription.charge_failed
        ::Notifier.reportedly_payment_failed(subscription)
        ::Notifier.user_payment_failed(subscription)
    
      elsif data_json['type'] == "charge.dispute.created"
        stripe_id = data_json['data']['object']['customer']
        subscription = ::Subscription.find_by_stripe_id(stripe_id)
        subscription.charge_disputed
        ::Notifier.reportedly_charge_disputed(subscription)
      
      elsif data_json['type'] == "customer.subscription.deleted"
        stripe_id = data_json['data']['object']['customer']
        subscription = ::Subscription.find_by_stripe_id(stripe_id)
        ::Notifier.reportedly_subscription_cancelled(subscription)

      elsif data_json['type'] == "customer.subscription.trial_will_end"
        stripe_id = data_json['data']['object']['customer']
        subscription = ::Subscription.find_by_stripe_id(stripe_id)
        ::Notifier.reportedly_trial_ending(subscription)

      end
      
      render nothing: true
      
    end
    
  end
end
