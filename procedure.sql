CREATE OR REPLACE PROCEDURE sp_doktor_izin_ve_randevu_iptali(
    p_doktor_id BIGINT,
    p_baslangic_tarihi DATE,
    p_bitis_tarihi DATE,
    p_iptal_nedeni TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_etkilenen_sayisi INT;
BEGIN
    INSERT INTO randevu_log (randevu_id, islem_tipi, aciklama, islem_zamani)
    SELECT 
        randevu_id, 
        'IPTAL', 
        'Doktor izni nedeniyle otomatik iptal: ' || p_iptal_nedeni,
        CURRENT_TIMESTAMP
    FROM randevu
    WHERE doktor_id = p_doktor_id 
      AND randevu_saati::DATE BETWEEN p_baslangic_tarihi AND p_bitis_tarihi
      AND durum = 'planlandi';

    UPDATE randevu
    SET durum = 'iptal_doktor',
        iptal_nedeni = p_iptal_nedeni,
        guncellenme_tarihi = CURRENT_TIMESTAMP,
        musaitlik_id = NULL 
    WHERE doktor_id = p_doktor_id 
      AND randevu_saati::DATE BETWEEN p_baslangic_tarihi AND p_bitis_tarihi
      AND durum = 'planlandi';

    GET DIAGNOSTICS v_etkilenen_sayisi = ROW_COUNT;

 
    DELETE FROM doktormusaitlik
    WHERE doktor_id = p_doktor_id 
      AND mesai_tarihi BETWEEN p_baslangic_tarihi AND p_bitis_tarihi;

    COMMIT;
    
    RAISE NOTICE 'Doktorun % ile % arasındaki izin işlemi tamamlandı. % adet randevu iptal edildi.', 
        p_baslangic_tarihi, p_bitis_tarihi, v_etkilenen_sayisi;
END;
$$;

CALL sp_doktor_izin_ve_randevu_iptali(
    4,                                                   
    '2025-01-10',                                        
    '2025-01-15',                                        
    'Yıllık İzin nedeniyle randevular iptal edilmiştir.' 
);










CREATE OR REPLACE PROCEDURE sp_randevu_olustur(
    p_hasta_id BIGINT,
    p_doktor_id BIGINT,
    p_poliklinik_id BIGINT,
    p_tarih_saat TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_musaitlik_id BIGINT;
    v_cakisma_kontrol INTEGER;
    v_randevu_id BIGINT;
BEGIN

    SELECT musaitlik_id INTO v_musaitlik_id
    FROM doktormusaitlik
    WHERE doktor_id = p_doktor_id
      AND poliklinik_id = p_poliklinik_id
      AND mesai_tarihi = p_tarih_saat::DATE
      AND p_tarih_saat::TIME >= baslangic_saati
      AND p_tarih_saat::TIME < bitis_saati;

    IF v_musaitlik_id IS NULL THEN
        RAISE EXCEPTION 'Doktor belirtilen tarih ve saatte bu poliklinikte çalışmamaktadır.';
    END IF;

    SELECT COUNT(*) INTO v_cakisma_kontrol
    FROM randevu
    WHERE doktor_id = p_doktor_id
      AND randevu_saati = p_tarih_saat
      AND durum NOT IN ('iptal_hasta', 'iptal_doktor');

    IF v_cakisma_kontrol > 0 THEN
        RAISE EXCEPTION 'Doktorun bu saatte başka bir randevusu mevcuttur.';
    END IF;

    INSERT INTO randevu (hasta_id, doktor_id, poliklinik_id, musaitlik_id, randevu_saati, durum)
    VALUES (p_hasta_id, p_doktor_id, p_poliklinik_id, v_musaitlik_id, p_tarih_saat, 'planlandi')
    RETURNING randevu_id INTO v_randevu_id;

    INSERT INTO bildirim (kullanici_id, randevu_id, tur, baslik, icerik, durum)
    VALUES (p_hasta_id, v_randevu_id, 'sms', 'Randevu Onayı', 
            p_tarih_saat || ' tarihli randevunuz başarıyla oluşturulmuştur.', 'gonderildi');

    RAISE NOTICE 'Randevu başarıyla oluşturuldu. ID: %', v_randevu_id;
END;
$$;

CALL sp_randevu_olustur(
    18,                 
    8,                   
    9,                   
    '2025-03-01 10:00:00' 
);








CREATE OR REPLACE PROCEDURE sp_randevu_durum_guncelle(
    p_randevu_id BIGINT,
    p_yeni_durum VARCHAR, -- 'tamamlandi', 'iptal_hasta', 'iptal_doktor'
    p_iptal_nedeni TEXT DEFAULT NULL,
    p_islem_yapan_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_eski_durum VARCHAR;
BEGIN
    -- Mevcut durumu al
    SELECT durum INTO v_eski_durum FROM randevu WHERE randevu_id = p_randevu_id;

    IF v_eski_durum IS NULL THEN
        RAISE EXCEPTION 'Randevu bulunamadı!';
    END IF;

    -- Güncelleme İşlemi
    UPDATE randevu
    SET durum = p_yeni_durum,
        iptal_nedeni = p_iptal_nedeni,
        guncellenme_tarihi = CURRENT_TIMESTAMP
    WHERE randevu_id = p_randevu_id;

    -- Log Tablosuna İşle
    -- Not: Trigger ile de yapılabilir ama prosedür içinde manuel kontrol istenmiş.
    INSERT INTO randevu_log (randevu_id, islem_tipi, islem_yapan_kullanici_id, aciklama)
    VALUES (p_randevu_id, 
            CASE WHEN p_yeni_durum LIKE 'iptal%' THEN 'IPTAL' ELSE 'DURUM_DEGISIKLIGI' END,
            p_islem_yapan_id,
            'Durum ' || v_eski_durum || ' -> ' || p_yeni_durum || ' olarak güncellendi. Neden: ' || COALESCE(p_iptal_nedeni, 'Yok'));
            
    RAISE NOTICE 'Randevu durumu güncellendi.';
END;
$$;


CALL sp_randevu_durum_guncelle(
    11,               
    'iptal_hasta',   
    'Acil şehir dışına çıkmam gerekti',
    16             
);
