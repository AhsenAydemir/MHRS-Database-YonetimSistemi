CREATE OR REPLACE PROCEDURE sp_randevu_olustur_tam_kontrol(
    p_hasta_id BIGINT,
    p_doktor_id BIGINT,
    p_poliklinik_id BIGINT,
    p_randevu_saati TIMESTAMP,
    p_islem_yapan_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_randevu_id BIGINT;
    v_musaitlik_id BIGINT; 
    v_cakisma_sayisi INTEGER;
BEGIN

    SELECT musaitlik_id INTO v_musaitlik_id
    FROM doktormusaitlik
    WHERE doktor_id = p_doktor_id 
      AND mesai_tarihi = p_randevu_saati::DATE 
      AND baslangic_saati <= p_randevu_saati::TIME 
      AND bitis_saati > p_randevu_saati::TIME;    

    IF v_musaitlik_id IS NULL THEN
        RAISE EXCEPTION 'HATA: Doktorun belirtilen tarih ve saatte çalışma mesaisi bulunamadı.';
    END IF;

    SELECT COUNT(*) INTO v_cakisma_sayisi
    FROM randevu
    WHERE doktor_id = p_doktor_id 
      AND randevu_saati = p_randevu_saati
      AND durum != 'iptal'; 

    IF v_cakisma_sayisi > 0 THEN
        RAISE EXCEPTION 'HATA: Bu saatte doktorun başka bir randevusu mevcut. (Dolu)';
    END IF;

    INSERT INTO randevu (hasta_id, doktor_id, poliklinik_id, musaitlik_id, randevu_saati, durum)
    VALUES (p_hasta_id, p_doktor_id, p_poliklinik_id, v_musaitlik_id, p_randevu_saati, 'planlandi')
    RETURNING randevu_id INTO v_randevu_id;

    IF v_randevu_id IS NULL THEN
        RAISE EXCEPTION 'Kritik Hata: Randevu oluşturulamadı.'; -- ROLLBACK 

    INSERT INTO bildirim (kullanici_id, randevu_id, tur, baslik, icerik, durum)
    VALUES (p_hasta_id, v_randevu_id, 'sistem', 'Randevu Başarılı', 'Randevunuz oluşturuldu.', 'gonderildi');

    INSERT INTO randevu_log (randevu_id, islem_tipi, islem_yapan_kullanici_id, aciklama)
    VALUES (v_randevu_id, 'OLUSTURMA', p_islem_yapan_id, 'Randevu başarıyla kaydedildi.');

    COMMIT;
    
    RAISE NOTICE 'İşlem Başarılı! Randevu ID: % oluşturuldu.', v_randevu_id;
END;
$$;


INSERT INTO doktormusaitlik (doktor_id, poliklinik_id, mesai_tarihi, baslangic_saati, bitis_saati, randevu_suresi_dk)
VALUES (8, 7, '2026-01-12', '09:00:00', '17:00:00', 15);

CALL sp_randevu_olustur_tam_kontrol(
    p_hasta_id => 1,               
    p_doktor_id => 7,              
    p_poliklinik_id => 8,           
    p_randevu_saati => '2026-01-12 10:00:00', 
    p_islem_yapan_id => 1           
);
 select * from kullanici
 select * from doktormusaitlik
  select * from randevu_log