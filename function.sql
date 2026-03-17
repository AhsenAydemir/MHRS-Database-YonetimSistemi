




CREATE OR REPLACE FUNCTION fn_hastane_performans_raporu()
RETURNS TABLE (
    hastane_adi VARCHAR,
    poliklinik_adi VARCHAR,
    toplam_randevu BIGINT,
    tamamlanan_muayene BIGINT,
    iptal_edilen_randevu BIGINT,
    doluluk_orani_yuzde NUMERIC,
    aktif_doktor_sayisi BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.ad AS hastane_adi,
        p.ad AS poliklinik_adi,
        COUNT(r.randevu_id) AS toplam_randevu,
        SUM(CASE WHEN r.durum = 'tamamlandi' THEN 1 ELSE 0 END) AS tamamlanan_muayene,
        SUM(CASE WHEN r.durum LIKE 'iptal%' THEN 1 ELSE 0 END) AS iptal_edilen_randevu,
        ROUND(
            (SUM(CASE WHEN r.durum = 'tamamlandi' THEN 1 ELSE 0 END)::NUMERIC / 
            NULLIF(COUNT(r.randevu_id), 0)) * 100, 2
        ) AS doluluk_orani_yuzde,
        (SELECT COUNT(DISTINCT d.doktor_id) FROM doktor d 
         WHERE d.hastane_id = h.hastane_id AND d.bolum_id = p.bolum_id) AS aktif_doktor_sayisi
    FROM 
        hastane h
    JOIN 
        poliklinik p ON h.hastane_id = p.hastane_id
    LEFT JOIN 
        randevu r ON p.poliklinik_id = r.poliklinik_id
    GROUP BY 
        h.ad, p.ad, h.hastane_id, p.bolum_id
    ORDER BY 
        hastane_adi, toplam_randevu DESC;
END;
$$;


SELECT * FROM fn_hastane_performans_raporu();















CREATE OR REPLACE FUNCTION fn_hesapla_doktor_performans(
    p_doktor_id BIGINT, 
    p_yil INT, 
    p_ay INT
)
RETURNS NUMERIC 
LANGUAGE plpgsql
AS $$
DECLARE
    v_toplam_randevu INT;
    v_tamamlanan INT;
    v_iptal_orani NUMERIC;
    v_puan NUMERIC := 0;
BEGIN
    SELECT COUNT(*) INTO v_toplam_randevu
    FROM randevu
    WHERE doktor_id = p_doktor_id
      AND EXTRACT(YEAR FROM randevu_saati) = p_yil
      AND EXTRACT(MONTH FROM randevu_saati) = p_ay;

    IF v_toplam_randevu = 0 THEN 
        RETURN 0; 
    END IF;

    SELECT COUNT(*) INTO v_tamamlanan
    FROM randevu
    WHERE doktor_id = p_doktor_id
      AND durum = 'tamamlandi'
      AND EXTRACT(YEAR FROM randevu_saati) = p_yil
      AND EXTRACT(MONTH FROM randevu_saati) = p_ay;

    v_puan := v_tamamlanan * 10;

    SELECT 
        (COUNT(*) FILTER (WHERE durum = 'iptal_doktor')::NUMERIC / v_toplam_randevu) * 100 
    INTO v_iptal_orani
    FROM randevu
    WHERE doktor_id = p_doktor_id
      AND EXTRACT(YEAR FROM randevu_saati) = p_yil
      AND EXTRACT(MONTH FROM randevu_saati) = p_ay;

    IF v_iptal_orani < 5 THEN
        v_puan := v_puan + 50;
    END IF;

    RETURN ROUND(v_puan, 2);
END;
$$;

select * from  fn_hesapla_doktor_performans(8, 2026, 3) 


select * from kullanici









CREATE OR REPLACE FUNCTION fn_bolum_tercih_raporu()
RETURNS TABLE (
    bolum_adi VARCHAR,
    toplam_randevu_sayisi BIGINT,
    tekil_hasta_sayisi BIGINT, 
    tamamlanan_muayene BIGINT,
    tercih_orani_yuzde NUMERIC
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_genel_toplam_randevu BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_genel_toplam_randevu FROM randevu;

    RETURN QUERY
    SELECT 
        b.ad::VARCHAR AS bolum_adi,
        COUNT(r.randevu_id) AS toplam_randevu_sayisi,
        COUNT(DISTINCT r.hasta_id) AS tekil_hasta_sayisi,
        SUM(CASE WHEN r.durum = 'tamamlandi' THEN 1 ELSE 0 END) AS tamamlanan_muayene,
        ROUND(
            (COUNT(r.randevu_id)::NUMERIC / NULLIF(v_genel_toplam_randevu, 0)) * 100, 2
        ) AS tercih_orani_yuzde
    FROM 
        bolum b
    LEFT JOIN 
        poliklinik p ON b.bolum_id = p.bolum_id
    LEFT JOIN 
        randevu r ON p.poliklinik_id = r.poliklinik_id
    GROUP BY 
        b.bolum_id, b.ad
    ORDER BY 
        toplam_randevu_sayisi DESC; 
END;
$$;

SELECT * FROM fn_bolum_tercih_raporu();

select * from randevu_log







CREATE OR REPLACE FUNCTION fn_hastane_bolum_raporu(
    p_hastane_id BIGINT,
    p_baslangic_tarihi DATE,
    p_bitis_tarihi DATE
)
RETURNS TABLE (
    bolum_adi VARCHAR,
    toplam_randevu BIGINT,
    tamamlanan_randevu BIGINT,
    iptal_edilen_randevu BIGINT,
    doluluk_orani NUMERIC
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.ad AS bolum_adi,
        COUNT(r.randevu_id) AS toplam_randevu,
        COUNT(r.randevu_id) FILTER (WHERE r.durum = 'tamamlandi') AS tamamlanan_randevu,
        COUNT(r.randevu_id) FILTER (WHERE r.durum IN ('iptal_hasta', 'iptal_doktor')) AS iptal_edilen_randevu,
        CASE 
            WHEN COUNT(r.randevu_id) = 0 THEN 0.0
            ELSE ROUND((COUNT(r.randevu_id) FILTER (WHERE r.durum = 'tamamlandi')::NUMERIC / COUNT(r.randevu_id) * 100), 2)
        END AS doluluk_orani
    FROM 
        randevu r
    JOIN 
        poliklinik p ON r.poliklinik_id = p.poliklinik_id
    JOIN 
        bolum b ON p.bolum_id = b.bolum_id
    WHERE 
        p.hastane_id = p_hastane_id
        AND r.randevu_saati::DATE BETWEEN p_baslangic_tarihi AND p_bitis_tarihi
    GROUP BY 
        b.ad, b.bolum_id
    ORDER BY 
        toplam_randevu DESC;
END;
$$;


SELECT * FROM fn_hastane_bolum_raporu(
    8,            -- Hastane ID
    '2025-01-01', -- Başlangıç Tarihi
    '2075-12-31'  -- Bitiş Tarihi
);
