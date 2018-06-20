CREATE TABLE pokoje(
  pokoj_id number(3) PRIMARY KEY,
  numer varchar2(5),
  kategoria varchar2(30), -- vip i zwykle
  cena_za_dobe number(3),
  czy_wolny number(1),
  ilosc_lozek_pojedynczych number(2),
  ilosc_lozek_podwojnych number(2),
  specjalny_dodatek varchar2(30)
);

CREATE TABLE rezerwacje(
  rezerwacja_id number(3) PRIMARY KEY,
  id_goscia number(2) CONSTRAINT gosc_id NOT NULL,
  id_pokoju number(2) CONSTRAINT pokoj_id,
  status varchar2(30), -- zamowione(ok 200), przydzielone, oczekujace (gdy nie ma zadnego wolnego pokoju), do rozstrzygniecia (gdy pokoj nie odpowiada)
  data_rozpoczecia DATE,
  data_zakonczenia DATE,
  data_przybycia_do_hotelu DATE,
  koszt_pokoju number(6),
  koszty_dodatkowe number(6),
  notatka varchar2(255)
);

CREATE TABLE goscie(
  gosc_id number(3) PRIMARY KEY,
  imie varchar2(20),
  nazwisko varchar2(30),
  numer_dowodu varchar2(8),
  miasto varchar2(20),
  ulica_numer_domu varchar2(30),
  liczba_wizyt number(4)
);

INSERT into pokoje values (1, '2a', 'vip', 120, 0, 0, 1, 'balkon');
INSERT into pokoje values (2, '2b', 'zwykly', 100, 0, 4, 0, 'balkon');
INSERT into pokoje values (3, '2c', 'zwykly', 120, 0, 5, 1, 'basen');
INSERT into pokoje values (4, '2d', 'vip', 120, 0, 3, 1, 'basen');

INSERT into goscie values (1, 'Zbyszek', 'Zbyszowski', 'AAa4456','Zbyszkowice','Gdyniewska 09-123', 1);
INSERT into goscie values (2, 'Rysiek', 'Ryszardowski', 'ABa4456','Sopot','Sopocka 09-123', 3);
INSERT into goscie values (3, 'Janina', 'Kowalska', 'AuR4456','Warszawa','Marszalkowska 09-123', 1);
INSERT into goscie values (4, 'Franek', 'Franowski', 'rAa4456','Kielce','Kielce 09-123', 5);

INSERT into rezerwacje values (1, 2, 1, 'zamowione', TO_DATE('2018/07/09', 'yyyy/mm/dd'),TO_DATE('2018/07/16', 'yyyy/mm/dd'),null , 0, 0, '');
INSERT into rezerwacje values (2, 1, null, 'przydzielone', TO_DATE('2018/05/11', 'yyyy/mm/dd'),TO_DATE('2018/05/16', 'yyyy/mm/dd'),TO_DATE('2018/05/11', 'yyyy/mm/dd'), 500, 0, 'zaplacono');

-- wpisz nowego goscia
CREATE OR REPLACE PROCEDURE dodaj_goscia(gosc_id number, imie varchar2, nazwisko varchar2, numer_dowodu varchar2, miasto varchar2, ulica_nr_domu varchar2)
  IS
  BEGIN
    INSERT into goscie VALUES(gosc_id, imie, nazwisko, numer_dowodu, miasto, ulica_nr_domu, 1);
END dodaj_goscia;

BEGIN
    dodaj_goscia(6, 'Kasia','Kasinska','A28993','Zbyszkow','Kujawska 12/3');
END;

SELECT * FROM goscie;

--wypisanie pokoi wolnych miedzy data d1 a d2
CREATE OR REPLACE PROCEDURE wypisz_wolne_pokoje(d1 DATE, d2 DATE)
  IS
  pokoj_numer varchar2(5);
  BEGIN
    SELECT pokoje.numer INTO pokoj_numer FROM rezerwacje, pokoje WHERE rezerwacje.id_pokoju = pokoje.pokoj_id AND d1 <= data_rozpoczecia AND d2 >= data_zakonczenia;
END wypisz_wolne_pokoje;


BEGIN 
    wypisz_wolne_pokoje(TO_DATE('2018/07/09', 'yyyy/mm/dd'), TO_DATE('2018/07/16', 'yyyy/mm/dd'));
END;


--funkcja pomocnicza
CREATE OR REPLACE FUNCTION znajdz_goscia_po_dowodzie(nr_dowodu varchar2)
  Return number is 
    id_1 number(3);
  BEGIN
     SELECT goscie.gosc_id INTO id_1 FROM goscie WHERE numer_dowodu = nr_dowodu;
    RETURN id_1;
  END znajdz_goscia_po_dowodzie;


--dokonanie rezerwacji  
CREATE OR REPLACE PROCEDURE dodaj_rezerwacje(nr_dowodu varchar2, id_pokoju number,status varchar2, data_rozpoczecia DATE, data_zakonczenia DATE,notatka varchar2)
  IS
    id_goscia number(3);
    liczba_wizyt1 number(4);
    rezerwacja_id number(4);
  BEGIN
    SELECT COUNT(*) INTO rezerwacja_id FROM rezerwacje;
    id_goscia := znajdz_goscia_po_dowodzie(nr_dowodu);
    SELECT liczba_wizyt into liczba_wizyt1 FROM goscie WHERE id_goscia = goscie.gosc_id;
    liczba_wizyt1 := liczba_wizyt1 + 1;
    INSERT into rezerwacje values ((rezerwacja_id + 1), id_goscia, id_pokoju, status, data_rozpoczecia, data_zakonczenia,null, null, null, notatka);
    UPDATE goscie SET liczba_wizyt = liczba_wizyt1 WHERE goscie.gosc_id = id_goscia;
  END dodaj_rezerwacje;

-- gosc zglosil sie do hotelu
CREATE OR REPLACE PROCEDURE zgloszenie_goscia_do_hotelu(nr_dowodu varchar2, data_przybycia_do_hotelu date)
  is 
   id_goscia number(3);
  begin
   id_goscia := znajdz_goscia_po_dowodzie(nr_dowodu);
   UPDATE rezerwacje SET rezerwacje.data_przybycia_do_hotelu = data_przybycia_do_hotelu WHERE id_goscia = id_goscia;
END zgloszenie_goscia_do_hotelu;

--usun rezerwacje
CREATE OR REPLACE PROCEDURE usun_rezerwacje(numer_dowodu varchar2)
  is 
    id_goscia number(3);
  begin
    id_goscia := znajdz_goscia_po_dowodzie(numer_dowodu);
    DELETE FROM rezerwacje WHERE rezerwacje.id_goscia = id_goscia;
END usun_rezerwacje;

-- funkcja pomocnicza różnica dat
CREATE OR REPLACE FUNCTION diff_date(id_goscia1 number)
    return number is
        rozpoczecie date;
        zakonczenie date;
    begin
        SELECT data_rozpoczecia into rozpoczecie FROM rezerwacje WHERE rezerwacje.id_goscia = id_goscia1;
        SELECT data_zakonczenia into zakonczenie FROM rezerwacje WHERE rezerwacje.id_goscia = id_goscia1;
    return zakonczenie - rozpoczecie;
END;

-- przygotuj rachunek dla gościa (przyznając mu rabat jeśli jest częstym gościem)
CREATE OR REPLACE PROCEDURE rachunek(nr_dowodu number, dodatkowe_koszty number)
    is 
    id_goscia number(3);
    id_pokoju1 number(3);
    liczba_dni number(3);
    koszt number(6);
    liczba_wizyt number(3);
    cena_za_dobe1 number(4);
  begin
    id_goscia := znajdz_goscia_po_dowodzie(numer_dowodu);
    liczba_dni := diff_date(id_goscia);
    SELECT id_pokoju INTO id_pokoju1 FROM rezerwacje WHERE rezerwacje.id_goscia = id_goscia;
    SELECT liczba_wizyt INTO liczba_wizyt FROM goscie WHERE gosc_id = id_goscia;
        IF liczba_wizyt > 5 THEN dodatkowe_koszty := dodatkowe_koszty * 0.6; -- rabat
        ELSIF liczba_wizyt > 10 THEN dodatkowe_koszty := dodatkowe_koszty * 0.5; -- rabat
        END IF;
        SELECT cena_za_dobe INTO cena_za_dobe1 FROM pokoje WHERE rezerwacje.id_pokoju = id_pokoju1;
    koszt := liczba_dni * cena_za_dobe1 + dodatkowe_koszty;
    UPDATE rezerwacje SET koszt_pokoju = koszt, notatka = (notatka + ', wygenerowano rachunek');
    DBMS_OUTPUT.PUT_LINE('Koszt pokoju calkowity:  '||koszt);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('nie ma zadnych danych do usuniecia');
END rachunek;

-- wyznacz osoby, które dokonały rezerwacji, a jeszcze nie zgłosiły się danego dnia
CREATE OR REPLACE PROCEDURE nie_zgloszone_osoby
    is
        v_date date;
    begin
    SELECT SYSDATE INTO v_date FROM dual;
    SELECT goscie.imie, goscie.nazwisko, rezerwacja.rezerwacja_id FROM goscie, rezerwacje WHERE goscie.gosc_id = rezerwacje.id_goscia AND rezerwacje.data_rozpoczecia >= v_date AND rezerwacje.data_przybycia_do_hotelu != null;
END nie_zgloszone_osoby;


-- procedura dla każdego gościa hotelowego: oblicza ile razy i przez jaki okres czasu przebywał w hotelu 
--i wstawia te informacje do pustej tabeli: Podsum( id_goscia, imie, nazwisko, ile_razy, jak_dlugo)
    
CREATE TABLE podsum(
    id_goscia number(3) PRIMARY KEY,
    imie varchar2(20),
    nazwisko varchar2(30),
    ile_razy number(3),
    jak_dlugo number(4)
);
    
CREATE OR REPLACE PROCEDURE przebywanie_w_hotelu
    is
    jak_dlugo1 number(4);
    begin
        FOR licznik IN 1..(SELECT COUNT(gosc_id) FROM goscie) LOOP
            INSERT INTO podsum (id_goscia, imie, nazwisko, ile_razy) SELECT imie, nazwisko, liczba_wizyt FROM goscie WHERE gosc_id = licznik;
            jak_dlugo1 := diff_date(licznik);
            INSERT INTO podsum
        END LOOP;
END;

--procedura usuwa wszystkie rezerwacje dotyczące pobytów starszych niż z przed pięciu lat

CREATE OR REPLACE PROCEDURE usun_stare_rezerwacje
    is
    l_date date;
    begin
    l_date := ADD_MONTHS (SYSDATE, -5*12); -- 5 lat wstecz
    DELETE FROM rezerwacje WHERE rezerwacje.data_zakonczenia < l_date;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('nie ma zadnych danych do usuniecia');
END;

-- trigger spawdzajacy czy data rozpoczecia jest wczesniejsza niz data zakonczenia
CREATE OR REPLACE TRIGGER czy_data_sie_zgadza
    BEFORE INSERT OR UPDATE OR DELETE OF data_rozpoczecia, data_zakonczenia 
    ON rezerwacje
    FOR EACH ROW
    BEGIN
        :NEW.data_rozpoczecia < :NEW.data_zakonczenia;
    END;
    
-- trigger - wyzwalacz aktualizuje pola ile_razy i  jak_dlugo
CREATE OR REPLACE TRIGGER update_pola
    BEFORE INSERT OR UPDATE OR DELETE OF ile_razy, jak_dlugo
    ON podsum
    DECLARE 
    ile number(3);
BEGIN
    CASE
        WHEN INSERTING THEN
            ile = :NEW.data_zakonczenia - :NEW.data_rozpoczecia;
            UPDATE podsum WHERE id_goscia = :NEW.id_goscia SET jak_dlugo = jak_dlugo + ile, ile_razy = ile_razy + 1;
        WHEN DELETING
            ile = :OLD.data_zakonczenia - :OLD.data_rozpoczecia;
            UPDATE podsum WHERE id_goscia = :OLD.id_goscia SET jak_dlugo = jak_dlugo - ile, ile_razy = ile_razy - 1;
    END CASE;
END;


--Dokonaj rezerwacji pokoju dla VIP-a na jedną noc. Jeśli nie ma wolnego pokoju
--spełniającego oczekiwania gościa, wśród osób, które dokonały rezerwacji na pokój
--spełniający specyfikację VIP-a, wybierz jedną z nich - nie mającą statusu VIP i zamień jej
--rezerwację na rezerwację dla VIP-a. Skasowaną rezerwację na pokój zamień na
--zamówioną rezerwację.

--wypisanie pokoi wolnych dnia d1 dla vipa
CREATE OR REPLACE PROCEDURE wypisz_wolne_pokoje_vip(d1 DATE, wymaganie varchar2)
  IS
  pokoj_numer varchar2(5);
  pokoj_kategoria varchar(20);
  BEGIN
    SELECT pokoje.numer, pokoje.kategoria INTO pokoj_numer, pokoj_kategoria FROM rezerwacje, pokoje WHERE rezerwacje.id_pokoju = pokoje.pokoj_id AND d1 <= data_rozpoczecia AND d1 >= data_zakonczenia AND pokoje.specjalny_dodatek = wymaganie;
    DBMS_OUTPUT.PUT_LINE(pokoj_numer || ' ' || pokoj_kategoria);  
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('nie ma zadnych danych');
END wypisz_wolne_pokoje_vip;

-- procedura glowna dodania vipa
CREATE OR REPLACE PROCEDURE rezerwacja_dla_vipa(dzien date, wymaganie varchar2, ilosc_pojedynczych_lozek number, liczba_podwojnych_lozek number, nr_dowodu varchar2) -- wymaganie : basen, bar, balkon itd
IS 
dzien1 date;
ilosc_poj_lozek number(1);
ilosc_podw_lozek number(1);
pokoj_numer varchar2(5);
pokoj_kategoria varchar(20);
id_pokoju number(4);
rezerwacja_id number(4);
id_goscia number(4);
BEGIN
    SELECT pokoje.numer, pokoje.kategoria, pokoje.pokoj_id INTO pokoj_numer, pokoj_kategoria, id_pokoju FROM rezerwacje, pokoje WHERE rezerwacje.id_pokoju = pokoje.pokoj_id AND d1 < rezerwacje.data_rozpoczecia AND d1 >= rezerwacje.data_zakonczenia AND pokoje.specjalny_dodatek = wymaganie AND ROWNUM = 1 ;
    DBMS_OUTPUT.PUT_LINE(pokoj_numer || ' ' || pokoj_kategoria);
    IF pokoj_kategoria = 'vip' THEN
        dodaj_rezerwacje(nr_dowodu,id_pokoju, 'zamowione',dzien, dzien, 'vip');
    ELSIF pokoj_kategoria != 'vip' THEN
        pokoj_kategoria := 'vip';
    ELSE
        SELECT pokoje.numer, rezerwacja.rezerwacja_id, pokoje.pokoj_id, goscie.gosc_id INTO pokoj_numer, rezerwacja_id, id_pokoju, id_goscia FROM pokoje, rezerwacje, goscie WHERE rezerwacje.id_pokoju = pokoje.pokoj_id AND pokoje.specjalny_dodatek = wymaganie AND ROWNUM = 1 ;
         dodaj_rezerwacje(nr_dowodu, id_pokoju, 'zamowione',dzien, dzien, 'vip');
         UPDATE rezerwacje SET status = 'oczekujace' WHERE rezerwacje.id_goscia = id_goscia;
    END IF;
    EXCEPTION
WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('nie ma zadnych danych');
END rezerwacja_dla_vipa;
