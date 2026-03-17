
CREATE OR REPLACE FUNCTION func_randevu_ekleme_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO randevu_log (randevu_id, islem_tipi, aciklama, islem_zamani)
    VALUES (NEW.randevu_id, 'OLUSTURMA', 'Yeni randevu kaydı oluşturuldu.', CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_randevu_ekleme
AFTER INSERT ON randevu
FOR EACH ROW
EXECUTE FUNCTION func_randevu_ekleme_log();


INSERT INTO randevu (hasta_id, doktor_id, poliklinik_id, musaitlik_id, randevu_saati, durum)
VALUES (16, 6, 7, 1, '2025-03-01 11:00:00', 'planlandi');

SELECT * FROM randevu_log ORDER BY log_id DESC;








CREATE OR REPLACE FUNCTION fn_trg_randevu_bildirim_ekle()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO bildirim (kullanici_id, randevu_id, tur, baslik, icerik, durum)
    VALUES (NEW.hasta_id, NEW.randevu_id, 'sistem', 'Yeni Randevu', 
            'Randevunuz başarıyla oluşturuldu. Tarih: ' || NEW.randevu_saati, 'beklemede');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_randevu_ekle_bildirim
AFTER INSERT ON randevu
FOR EACH ROW
EXECUTE FUNCTION fn_trg_randevu_bildirim_ekle();

INSERT INTO randevu (hasta_id, doktor_id, poliklinik_id, musaitlik_id, randevu_saati)
VALUES (
    1,                    
    4,                    
    1,                    
    28,                   
    '2025-06-15 09:00:00' 
);









CREATE OR REPLACE FUNCTION doktor_silinince_randevu_iptali()
RETURNS TRIGGER AS $$
BEGIN

    
    UPDATE randevu
    SET durum = 'iptal_doktor',
        iptal_nedeni = 'Doktor sistemden kaydı silindiği için randevu otomatik iptal edildi.'
    WHERE doktor_id = OLD.doktor_id 
      AND durum = 'planlandi' 
      AND randevu_saati > CURRENT_TIMESTAMP;

    RAISE NOTICE 'Doktor (ID: %) siliniyor. Varsa aktif randevuları iptal statüsüne çekildi.', OLD.doktor_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doktor_silme_iptal
BEFORE DELETE ON doktor
FOR EACH ROW
EXECUTE FUNCTION doktor_silinince_randevu_iptali();










CREATE OR REPLACE FUNCTION fn_gelmedi_uyari_bildirimi()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.durum = 'gelmedi' AND (OLD.durum IS DISTINCT FROM 'gelmedi') THEN
        
        INSERT INTO bildirim (
            kullanici_id, 
            randevu_id, 
            tur, 
            baslik, 
            icerik, 
            durum
        )
        VALUES (
            NEW.hasta_id,
            NEW.randevu_id,
            'email', -- Veya SMS
            'Randevuya Katılım Durumu',
            'Sayın hastamız, ' || NEW.randevu_saati || ' tarihli randevunuza gelmediğiniz tespit edilmiştir. Lütfen randevularınıza sadık kalınız veya önceden iptal ediniz.',
            'beklemede'
        );
        
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_randevu_gelmedi_takip
AFTER UPDATE ON randevu
FOR EACH ROW
EXECUTE FUNCTION fn_gelmedi_uyari_bildirimi();


UPDATE randevu SET durum = 'gelmedi' WHERE randevu_id = 20; 

SELECT * FROM bildirim ORDER BY bildirim_id DESC;