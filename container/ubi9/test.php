<?php
date_default_timezone_set('Asia/Tokyo');
mb_internal_encoding('UTF-8');

// PDO接続(entrypointで上書きする)
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
];
%db%

// TABLEが既に作成されているかもしれないことを考慮して、存在していたらDROPする
$stmt = $db->prepare('SELECT COUNT(*) AS CNT FROM USER_TABLES WHERE TABLE_NAME = :table_name');
$stmt->bindValue(':table_name', 'TEST', PDO::PARAM_STR);
$stmt->execute();
$row = $stmt->fetch(PDO::FETCH_ASSOC);
$stmt->closeCursor();
if ($row != FALSE && $row['CNT'] > 0) {
    $stmt = $db->prepare('DROP TABLE TEST');
    $stmt->execute();
    $stmt->closeCursor();
}

// TABLE作成
$stmt = $db->prepare('CREATE TABLE TEST(ID VARCHAR2(32) NOT NULL PRIMARY KEY, NAME VARCHAR2(2048))');
$stmt->execute();
$stmt->closeCursor();

// INSERT
$stmt = $db->prepare('INSERT INTO TEST (ID, NAME) VALUES (:id, :name)');
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->bindValue(':name', '白銀', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'INSERT');

// UPDATE
$stmt = $db->prepare('UPDATE TEST SET NAME = :name WHERE ID = :id');
$stmt->bindValue(':name', 'しろがね', PDO::PARAM_STR);
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'UPDATE');

// DELETE
$stmt = $db->prepare('DELETE FROM TEST WHERE ID = :id');
$stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
$stmt->execute();
$stmt->closeCursor();
output($db, 'DELETE');

// DROP TABLE
$stmt = $db->prepare('DROP TABLE TEST');
$stmt->execute();
$stmt->closeCursor();

// 出力用関数
function output($db, $crud) {
    $stmt = $db->prepare('SELECT * FROM TEST WHERE ID = :id ORDER BY ID');
    $stmt->bindValue(':id', 'shirogane', PDO::PARAM_STR);
    $stmt->execute();
    $data = [];
    while (($row = $stmt->fetch(PDO::FETCH_ASSOC)) != false) {
        $data[] = $row;
    }
    $stmt->closeCursor();
    if (PHP_SAPI === 'cli') {
        echo $crud."\n".print_r($data, TRUE)."\n";
    } else {
        echo $crud.'<br><pre>'.print_r($data, TRUE).'</pre><br>';
    }
}
