# QUESTAO 1

USE world;

DELIMITER //
CREATE PROCEDURE sp_paises_regiao(IN p_regiao VARCHAR(50))
BEGIN
    SELECT Name, SurfaceArea, Population
    FROM country
    WHERE Region = p_regiao
    ORDER BY SurfaceArea DESC;
END //
DELIMITER ;

CALL sp_paises_regiao('Southern Europe');

# QUESTAO 2

USE sakila;

DELIMITER //
CREATE PROCEDURE sp_filmes_categoria_preco(
    IN p_categoria VARCHAR(25),
    IN p_valor DECIMAL(4,2),
    OUT p_qtd INT
)
BEGIN
    SELECT f.title, f.rental_rate
    FROM film f
    INNER JOIN film_category fc ON f.film_id = fc.film_id
    INNER JOIN category c ON fc.category_id = c.category_id
    WHERE c.name = p_categoria
      AND f.rental_rate = p_valor
    ORDER BY f.title ASC;

    SELECT COUNT(*) INTO p_qtd
    FROM film f
    INNER JOIN film_category fc ON f.film_id = fc.film_id
    INNER JOIN category c ON fc.category_id = c.category_id
    WHERE c.name = p_categoria
      AND f.rental_rate = p_valor;
END //
DELIMITER ;

CALL sp_filmes_categoria_preco('Horror', 4.99, @qtd);
SELECT @qtd AS quantidade_encontrada;

# QUESTAO 3

USE classicmodels;

DELIMITER //
CREATE PROCEDURE sp_receita_escritorios()
BEGIN
    DECLARE v_office INT DEFAULT 1;
    DECLARE v_cidade VARCHAR(50);
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_resultado TEXT DEFAULT '';

    WHILE v_office <= 7 DO
        SELECT o.city, IFNULL(SUM(p.amount), 0)
        INTO v_cidade, v_total
        FROM offices o
        LEFT JOIN employees e ON o.officeCode = e.officeCode
        LEFT JOIN customers c ON e.employeeNumber = c.salesRepEmployeeNumber
        LEFT JOIN payments p ON c.customerNumber = p.customerNumber
        WHERE o.officeCode = v_office
        GROUP BY o.officeCode, o.city;

        IF v_office = 1 THEN
            SET v_resultado = CONCAT(v_cidade, ': ', v_total);
        ELSE
            SET v_resultado = CONCAT(v_resultado, ' | ', v_cidade, ': ', v_total);
        END IF;

        SET v_office = v_office + 1;
    END WHILE;

    SELECT v_resultado AS receita_por_escritorio;
END //
DELIMITER ;

CALL sp_receita_escritorios();
SELECT SUM(amount) AS total_geral_payments FROM payments;

# QUESTAO 4
USE classicmodels;

DELIMITER //
CREATE FUNCTION fn_dias_entrega(p_orderNumber INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_dias INT;

    SELECT DATEDIFF(shippedDate, orderDate)
    INTO v_dias
    FROM orders
    WHERE orderNumber = p_orderNumber;

    RETURN v_dias;
END //
DELIMITER ;

SELECT orderNumber, orderDate, shippedDate, fn_dias_entrega(orderNumber) AS dias_entrega
FROM orders
WHERE fn_dias_entrega(orderNumber) IS NOT NULL
ORDER BY dias_entrega DESC, orderNumber ASC
LIMIT 5;

# QUESTAO 5
USE world;

DELIMITER //
CREATE FUNCTION fn_qtd_idiomas_oficiais(p_code CHAR(3))
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_qtd INT;

    SELECT COUNT(*)
    INTO v_qtd
    FROM countrylanguage
    WHERE CountryCode = p_code
      AND IsOfficial = 'T';

    RETURN v_qtd;
END //
DELIMITER ;

SELECT Code, Name, fn_qtd_idiomas_oficiais(Code) AS idiomas_oficiais
FROM country
WHERE fn_qtd_idiomas_oficiais(Code) >= 3
ORDER BY idiomas_oficiais DESC, Name ASC;

# QUESTAO 6
USE sakila;

DELIMITER //
CREATE FUNCTION fn_categoria_favorita(p_customer_id INT)
RETURNS VARCHAR(25)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_categoria VARCHAR(25);

    SELECT c.name
    INTO v_categoria
    FROM rental r
    INNER JOIN inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN film_category fc ON i.film_id = fc.film_id
    INNER JOIN category c ON fc.category_id = c.category_id
    WHERE r.customer_id = p_customer_id
    GROUP BY c.category_id, c.name
    ORDER BY COUNT(*) DESC, c.name ASC
    LIMIT 1;

    RETURN IFNULL(v_categoria, 'Nenhuma');
END //
DELIMITER ;

SELECT customer_id, first_name, last_name, fn_categoria_favorita(customer_id) AS favorita
FROM customer
WHERE customer_id BETWEEN 1 AND 5;


SELECT fn_categoria_favorita(customer_id) AS categoria, COUNT(*) AS total_clientes
FROM customer
GROUP BY categoria
ORDER BY total_clientes DESC
LIMIT 3;

# QUESTAO 7
USE classicmodels;

DELIMITER //
CREATE TRIGGER trg_padroniza_linha
BEFORE INSERT ON productlines
FOR EACH ROW
BEGIN
    SET NEW.productLine = TRIM(NEW.productLine);

    IF NEW.textDescription IS NULL OR TRIM(NEW.textDescription) = '' THEN
        SET NEW.textDescription = CONCAT('Linha ', NEW.productLine, ' (descrição pendente)');
    END IF;
END //
DELIMITER ;


INSERT INTO productlines (productLine, textDescription) VALUES ('Bicycles   ', NULL);
INSERT INTO productlines (productLine, textDescription) VALUES ('Tractors', 'Tratores agrícolas em miniatura');

SELECT productLine, textDescription FROM productlines WHERE productLine IN ('Bicycles', 'Tractors');

# QUESTAO 8
USE classicmodels;

DELIMITER //
CREATE TRIGGER trg_protege_cliente
BEFORE DELETE ON customers
FOR EACH ROW
BEGIN
    DECLARE v_pedidos INT;

    SELECT COUNT(*) INTO v_pedidos
    FROM orders
    WHERE customerNumber = OLD.customerNumber;

    IF v_pedidos > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente possui pedidos e não pode ser excluído';
    END IF;
END //
DELIMITER ;

DELETE FROM customers WHERE customerNumber = 103; -- Deve disparar erro do trigger
DELETE FROM customers WHERE customerNumber = 125; -- Deve excluir com sucesso


# QUESTAO 9
USE world;

DELIMITER //
CREATE TRIGGER trg_sincroniza_pop_pais
AFTER UPDATE ON city
FOR EACH ROW
BEGIN
    IF NEW.Population <> OLD.Population THEN
        UPDATE country
        SET Population = Population + (NEW.Population - OLD.Population)
        WHERE Code = NEW.CountryCode;
    END IF;
END //
DELIMITER ;

SELECT Code, Name, Population FROM country WHERE Code = 'BRA';

UPDATE city SET Population = Population + 1000 WHERE Name = 'Belo Horizonte' AND CountryCode = 'BRA';
UPDATE city SET Population = Population - 300 WHERE Name = 'Contagem' AND CountryCode = 'BRA';
UPDATE city SET District = 'Minas Gerais' WHERE Name = 'Betim' AND CountryCode = 'BRA';

SELECT Code, Name, Population FROM country WHERE Code = 'BRA';

# QUESTAO 10
USE sakila;

CREATE TABLE cliente_status_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    ativo_antes TINYINT,
    ativo_depois TINYINT,
    alterado_em DATETIME
);

DELIMITER //
CREATE TRIGGER trg_log_status_cliente
AFTER UPDATE ON customer
FOR EACH ROW
BEGIN
    IF OLD.active <> NEW.active THEN
        INSERT INTO cliente_status_log (customer_id, ativo_antes, ativo_depois, alterado_em)
        VALUES (NEW.customer_id, OLD.active, NEW.active, NOW());
    END IF;
END //

CREATE PROCEDURE sp_desativar_cliente(IN p_cliente INT)
BEGIN
    DECLARE v_pendentes INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE customer
    SET active = 0
    WHERE customer_id = p_cliente AND active = 1;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente inexistente ou já inativo';
    END IF;

    SELECT COUNT(*) INTO v_pendentes
    FROM rental
    WHERE customer_id = p_cliente AND return_date IS NULL;

    IF v_pendentes > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente com filmes não devolvidos';
    END IF;

    COMMIT;
END //
DELIMITER ;

CALL sp_desativar_cliente(1);
CALL sp_desativar_cliente(5); 
CALL sp_desativar_cliente(1); 

SELECT * FROM cliente_status_log;

# QUESTAO 11
USE classicmodels;

CREATE TABLE transferencia_funcionario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    employeeNumber INT,
    escritorio_antigo VARCHAR(10),
    escritorio_novo VARCHAR(10),
    transferido_em DATETIME
);

DELIMITER //
CREATE TRIGGER trg_log_escritorio
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF OLD.officeCode <> NEW.officeCode THEN
        INSERT INTO transferencia_funcionario (employeeNumber, escritorio_antigo, escritorio_novo, transferido_em)
        VALUES (NEW.employeeNumber, OLD.officeCode, NEW.officeCode, NOW());
    END IF;
END //

CREATE PROCEDURE sp_transferir_funcionario(IN p_funcionario INT, IN p_escritorio VARCHAR(10))
BEGIN
    DECLARE v_subordinados INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE employees
    SET officeCode = p_escritorio
    WHERE employeeNumber = p_funcionario;

    SELECT COUNT(*) INTO v_subordinados
    FROM employees
    WHERE reportsTo = p_funcionario;

    IF v_subordinados > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Gerentes não podem ser transferidos';
    END IF;

    COMMIT;
END //
DELIMITER ;

CALL sp_transferir_funcionario(1165, '4'); 
CALL sp_transferir_funcionario(1143, '4'); 
CALL sp_transferir_funcionario(1166, '99'); 

SELECT * FROM transferencia_funcionario;

# QUESTAO 12
USE world;

DROP TRIGGER IF EXISTS trg_sincroniza_pop_pais;

CREATE TABLE censo_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    CountryCode CHAR(3),
    percentual DECIMAL(5,2),
    situacao VARCHAR(60),
    registrado_em DATETIME
);

DELIMITER //
CREATE PROCEDURE sp_aplicar_censo(IN p_pais CHAR(3), IN p_percentual DECIMAL(5,2))
BEGIN
    DECLARE v_nova_pop BIGINT;
    DECLARE v_fator DECIMAL(10,4);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_percentual <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Percentual deve ser positivo';
    END IF;

    SET v_fator = 1 + (p_percentual / 100);

    START TRANSACTION;

    UPDATE city
    SET Population = ROUND(Population * v_fator)
    WHERE CountryCode = p_pais;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'País sem cidades cadastradas';
    END IF;

    SAVEPOINT apos_cidades;

    UPDATE country
    SET Population = ROUND(Population * v_fator)
    WHERE Code = p_pais;

    SELECT Population INTO v_nova_pop
    FROM country
    WHERE Code = p_pais;

    IF v_nova_pop > 2000000000 THEN
        ROLLBACK TO SAVEPOINT apos_cidades;
        INSERT INTO censo_log (CountryCode, percentual, situacao, registrado_em)
        VALUES (p_pais, p_percentual, 'Somente cidades atualizadas', NOW());
    ELSE
        INSERT INTO censo_log (CountryCode, percentual, situacao, registrado_em)
        VALUES (p_pais, p_percentual, 'Cidades e país atualizados', NOW());
    END IF;

    COMMIT;
END //
DELIMITER ;

-- 5) Testes
CALL sp_aplicar_censo('BRA', 5.00); 
CALL sp_aplicar_censo('CHN', 60.00); 
CALL sp_aplicar_censo('ATA', 10.00); 

SELECT * FROM censo_log;

# QUESTAO 13
CREATE SCHEMA IF NOT EXISTS dw_world;
USE dw_world;

CREATE TABLE kv_pais (
    chave VARCHAR(20) PRIMARY KEY,
    valor JSON
);

INSERT INTO dw_world.kv_pais (chave, valor)
SELECT 
    CONCAT('pais:', Code),
    JSON_OBJECT(
        'nome', Name,
        'populacao', Population,
        'expectativa', LifeExpectancy
    )
FROM world.country
WHERE Continent = 'South America'
ON DUPLICATE KEY UPDATE
    valor = VALUES(valor);

SELECT 
    chave,
    valor->>'$.nome' AS nome,
    CAST(valor->>'$.populacao' AS UNSIGNED) AS populacao
FROM dw_world.kv_pais
WHERE chave = 'pais:BRA';

# QUESTAO 14
CREATE SCHEMA IF NOT EXISTS origem_world;
CREATE SCHEMA IF NOT EXISTS dw_world;

CREATE TABLE origem_world.cidade_br AS
SELECT ID, Name, District, Population
FROM world.city
WHERE CountryCode = 'BRA';

ALTER TABLE origem_world.cidade_br ADD PRIMARY KEY (ID);

CREATE TABLE dw_world.cidade_br_snapshot AS
SELECT * FROM origem_world.cidade_br;

ALTER TABLE dw_world.cidade_br_snapshot ADD PRIMARY KEY (ID);

UPDATE origem_world.cidade_br SET Population = Population + 5000 WHERE Name = 'Uberlândia';
UPDATE origem_world.cidade_br SET District = 'MG' WHERE Name = 'Juiz de Fora';
UPDATE origem_world.cidade_br SET Population = 0 WHERE Name = 'Sabará';

SELECT 
    o.ID,
    o.Name AS cidade,
    s.District AS distrito_antigo,
    o.District AS distrito_novo,
    s.Population AS pop_antiga,
    o.Population AS pop_nova
FROM origem_world.cidade_br o
INNER JOIN dw_world.cidade_br_snapshot s ON o.ID = s.ID
WHERE o.District <> s.District OR o.Population <> s.Population;

# QUESTAO 15
CREATE SCHEMA IF NOT EXISTS dw_classicmodels;
USE dw_classicmodels;

CREATE TABLE vendas_pais_ano (
    pais VARCHAR(50),
    ano INT,
    pedidos INT,
    receita DECIMAL(14,2),
    PRIMARY KEY (pais, ano)
);

CREATE TABLE etl_execucao (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ano INT,
    linhas INT,
    situacao VARCHAR(20),
    executado_em DATETIME
);

DELIMITER //
CREATE PROCEDURE sp_etl_vendas_pais(IN p_ano INT)
BEGIN
    DECLARE v_linhas INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO dw_classicmodels.etl_execucao (ano, linhas, situacao, executado_em)
        VALUES (p_ano, 0, 'ERRO', NOW());
        RESIGNAL;
    END;

    -- E (Extract): Staging temporária
    DROP TEMPORARY TABLE IF EXISTS stg_vendas;
    CREATE TEMPORARY TABLE stg_vendas AS
    SELECT 
        c.country AS pais,
        o.orderNumber AS pedido,
        (od.quantityOrdered * od.priceEach) AS valor
    FROM classicmodels.orders o
    INNER JOIN classicmodels.customers c ON o.customerNumber = c.customerNumber
    INNER JOIN classicmodels.orderdetails od ON o.orderNumber = od.orderNumber
    WHERE YEAR(o.orderDate) = p_ano
      AND o.status <> 'Cancelled';

    START TRANSACTION;

    DELETE FROM dw_classicmodels.vendas_pais_ano WHERE ano = p_ano;

    INSERT INTO dw_classicmodels.vendas_pais_ano (pais, ano, pedidos, receita)
    SELECT 
        UPPER(pais),
        p_ano,
        COUNT(DISTINCT pedido),
        SUM(valor)
    FROM stg_vendas
    GROUP BY UPPER(pais);

    SET v_linhas = ROW_COUNT();

    IF v_linhas = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nenhuma venda encontrada para o ano';
    END IF;

    INSERT INTO dw_classicmodels.etl_execucao (ano, linhas, situacao, executado_em)
    VALUES (p_ano, v_linhas, 'OK', NOW());

    COMMIT;
    DROP TEMPORARY TABLE IF EXISTS stg_vendas;
END //
DELIMITER ;

-- Testes
CALL sp_etl_vendas_pais(2004);
CALL sp_etl_vendas_pais(2004); 
CALL sp_etl_vendas_pais(1999);

SELECT 
    RANK() OVER (ORDER BY receita DESC) AS ranking,
    pais,
    pedidos,
    receita
FROM dw_classicmodels.vendas_pais_ano
WHERE ano = 2004
LIMIT 3;
