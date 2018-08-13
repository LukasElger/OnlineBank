class Ueberweisung
  def initialize(quelle, ziel, betrag, verwendungszweck)
    @konto = quelle
    @ziel_konto_nr = ziel
    @betrag = betrag
    @verwendungszweck = verwendungszweck
  end

  def to_csv
    "#{@konto},#{@ziel_konto_nr},#{@betrag},#{@verwendungszweck}"
  end

  def betrag
    @betrag
  end

  def konto
    @konto
  end

  def ziel_konto_nr
    @ziel_konto_nr
  end

  def verwendungszweck
    @verwendungszweck
  end
end
