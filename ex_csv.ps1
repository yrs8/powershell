#定数
$TARGETPATH = '\powershell\work\ctab'
$OUTFILENM  = "C:\powershell\work\export-crontab_$((Get-Date).ToString("yyyyMMddHHmm")).csv"

$exportData = New-Object System.Collections.ArrayList

Write-Host "crontabログの解析処理を開始します。"

# Main処理
function main () {

    $ctabArray = @();

    foreach ( $cLine in (Get-Content $TARGETPATH\*.txt | Select-String -NotMatch "^#") ) {
    #foreach ($cLine in (Get-Content $TARGETPATH\*.txt).TrimEnd("/s[a-z|A-Z]|`/]")){
    
        #cron情報取得、2つ以上のスペースを1つのスペースに変換
        $cmdlnTmp   = ( $cLine -split ">"  )[0] -replace "  * ", " "
        $argSplit   = ( $cLine -split "\s" )

        #cron時刻削除、実行コマンド取得
        for ( $i=5; $i -lt $argSplit.Length; $i++ ) {
            $cronCmd += $argSplit[$i] + " "
        }

        $cronCmd    = $cronCmd.Trim()
        $ctabArray += $cronCmd

        #初期化
        $cronCmd = ""

    }
    
    #ソート・重複データ削除
    $ctabArray = $ctabArray | Sort-Object | Get-Unique

    #CSV用オブジェクト作成
    $value = GetInstance

    #cron実行コマンド取得
    for ( $i=1; $i -lt $ctabArray.Length+1; $i++ ) {
        $num = $i.ToString("000")
        $columnName = "column$num"

        #cron実行コマンド
        $value."$columnName" = $ctabArray[$i-1]
    }

    #取得データを出力オブジェクトに設定
    [void]$exportData.Add($value)

    #ホストごとにcron実行コマンドを確認
    $lsItem = Get-ChildItem $TARGETPATH -Recurse -Include *.txt

    Foreach ( $fileName in $lsItem ) {

        #CSV用オブジェクト作成
        $value = GetInstance

        #ホスト名設定
        $value.column000 = (( $fileName -split "crontab-" )[1] -split ".txt" )[0]

        #コマンド実行時刻取得
        for ( $i=1; $i -lt $ctabArray.Length+1; $i++ ) {

            $num        = $i.ToString("000")
            $columnName = "column$num"

            #実行時刻取得処理
            $cronTmp   = ( (Select-String -NotMatch "^#" $fileName | Select-String -SimpleMatch $ctabArray[$i-1] ).Line -split ">"  )[0] -replace "  * ", " "
            $cronTime  = ( $cronTmp -split "\s" )[0,1,2,3,4].Trim() -join " "
            
            #カラム設定
            if ( $cronTime -ne "" ){
                $value."$columnName" = $cronTime
            }
        }

        #取得データを出力オブジェクトに設定
        [void]$exportData.Add($value)
    }

    #CSV出力
    $exportData | Export-Csv $OUTFILENM -Encoding Default -NoTypeInformation
    
}

#CSVオブジェクト
function GetInstance () {
    $value = New-Object PSObject -Property @{
        column000  = $null;
    }

    #プロパティ追加 (columnxxx)
    for ( $i=1; $i -lt $ctabArray.Length+1; $i++ ) {
        $num = $i.ToString("000")
        $columnName = "column$num"
        $value | Add-Member -MemberType NoteProperty -Name "$columnName" -Value $null
    }

    return $value
}

# Main処理実行
main
