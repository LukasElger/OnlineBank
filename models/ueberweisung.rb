class Ueberweisung
  include DataMapper::Resource
  property :id,           Serial
  property :ziel,          String#, required: true
  property :betrag,          Integer#, required: true
  property :verwendungszweck,          String#, required: true

  belongs_to :konto, "Konto"
end
