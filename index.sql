CREATE INDEX idx_hasta_randevu_gecmisi
ON randevu(hasta_id);



CREATE INDEX idx_doktor_aktif_randevular
ON randevu(doktor_id, durum);


CREATE INDEX idx_randevu_tarih_araligi
ON randevu(randevu_saati);


CREATE INDEX idx_doktor_hastane_bolum 
ON doktor(hastane_id, bolum_id);


