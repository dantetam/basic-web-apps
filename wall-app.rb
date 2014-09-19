require "sinatra"     # Load the Sinatra web framework
require "data_mapper" # Load the DataMapper database library

require "./database_setup"

class Message
  include DataMapper::Resource

  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
end

DataMapper.finalize()
DataMapper.auto_upgrade!()

get("/") do
  records = Message.all(order: :created_at.desc)
  erb(:index, locals: { messages: records })
end

post("/messages") do

  message_body = params["body"]

  if message_body.include? "You're"
    message = Message.create(body: "No, you're " << message_body[6..message_body.length], created_at: DateTime.now)
  else
    message = Message.create(body: params["body"].reverse, created_at: DateTime.now)
  end

  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end
