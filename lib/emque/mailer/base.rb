require "erb"
require "sendgrid-ruby"

module Emque
  module Mailer
    NotImplemented = Class.new(StandardError)

    class Base
      # TODO: make this configurable
      SEND_ENVS = ["staging", "production"]
      extend Forwardable

      class << self
        def layout(name = false)
          @layout = name if name
          @layout
        end

        def bcc(email = false)
          @bcc = email if email
          @bcc
        end

        # TODO: make this a configurable default as well
        def from(email = false)
          @from = email if email
          @from
        end

        # TODO: **heckles self for using method missing** - give this love
        def method_missing(method, *args, &block)
          if instance_methods.include?(method)
            mailer = new
            mailer.send(method, *args, &block)
            mailer
          else
            super
          end
        end
      end

      def_delegators :mailer, :to, :to_name, :from, :from_name, :subject, :text,
                              :to=, :to_name=, :from=, :from_name=, :subject=, :text=,
                              :html, :cc, :bcc, :reply_to, :date, :attachments,
                              :html=, :cc=, :bcc=, :reply_to=, :date=, :attachments=,
                              :smtpapi

      attr_accessor :template

      # TODO: let a configurable adapter handle this
      def initialize
        self.mailer = SendGrid::Mail.new
        smtpapi.add_category Emque::Consuming.application.config.app_name
        smtpapi.add_category Inflecto.underscore(self.class.name)
        self
      end

      # TODO: Sendgrid only
      def categories
        smtpapi.category
      end

      # TODO: Sendgrid only
      def category=(*cats)
        smtpapi.set_categories([].tap { |categories|
          cats.flatten.each { |cat| categories << cat }
          smtpapi.category.each { |cat| categories << cat }
        }.uniq)
      end

      def deliver(&block)
        generate

        [:bcc, :from].each do |class_attr|
          if mailer.send(class_attr).nil?
            mailer.send("#{class_attr}=", self.class.send(class_attr))
          end
        end

        block.call if block_given?

        self
      end

      # TODO: should be possible to 'deliver' through APIs, not just the Mail gem
      def deliver!
        deliver do
          begin
            if SEND_ENVS.include?(Emque::Consuming.application.emque_env)
              # TODO: This needs to be a SendGrid::Client instance. Another
              # thing for the adapter to handle
              SG.send(mailer)
            else
              write_to_logger
            end
          ensure
            persist
          end
        end
      end

      def generate
        if template_exists?(:html)
          self.html = build_content(:html)
          self.html = build_layout(:html, html) if layout_exists?(:html)
        end

        if template_exists?(:text)
          self.text = build_content(:text)
          self.text = build_layout(:text, text) if layout_exists?(:text)
        end

        { :html => html, :text => text }
      end

      private

      attr_accessor :mailer

      def build_content(type)
        ERB.new(
          File.read(template_filename(type)),
          nil,
          "-"
        ).result(get_binding)
      end

      def build_layout(type, content)
        ERB.new(
          File.read(layout_filename(type)),
          nil,
          "-"
        ).result(get_binding{ content })
      end

      def data
        {}.tap { |h|
          [
            :to, :to_name, :from, :from_name, :subject,
            :cc, :bcc, :reply_to, :date, :categories
          ].each do |attr|
            h[attr] = send(attr)
          end
        }
      end

      def get_binding
        binding
      end

      def layout_exists?(type)
        self.class.layout && File.exists?(layout_filename(type))
      end

      def layout_filename(type)
        File.join(
          Emque::Consuming.application.root,
          "service",
          "views",
          "layouts",
          "#{self.class.layout}.#{type}.erb"
        )
      end

      def logger
        Emque::Consuming.application.logger
      end

      # TODO: this should be configurable / optional
      def persist
        raise NotImplemented, "#persist must be defined"
      end

      def template_exists?(type)
        File.exists?(template_filename(type))
      end

      def template_filename(type)
        File.join(
          Emque::Consuming.application.root,
          "service",
          "views",
          Inflecto.underscore(self.class.name),
          "#{template}.#{type}.erb"
        )
      end

      def write_to_logger
        logger.info <<-EMAIL
------ START EMAIL ------
class: #{self.class.name}
template: #{template}
layout: #{self.class.layout}
mailer: #{mailer}
to: #{to}
to_name: #{to_name}
from: #{from}
from_name: #{from_name}
subject: #{subject}
cc: #{cc}
bcc: #{bcc}
reply_to: #{reply_to}
date: #{date}
attachments: #{attachments.count}
------ BODY HTML ------
#{html}
------ BODY TEXT ------
#{text}
------ END EMAIL ------
        EMAIL
      end
    end
  end
end
