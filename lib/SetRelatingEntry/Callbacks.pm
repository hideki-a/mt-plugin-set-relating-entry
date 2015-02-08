# ベース: https://github.com/movabletype/Documentation/wiki/Japanese-plugin-dev-3-2
# カスタムフィールド参考: http://junnama.alfasado.net/online/2008/02/post_152.html
package SetRelatingEntry::Callbacks;
use strict;
use List::Compare;
use CustomFields::Util qw( get_meta save_meta );

# [更新時の処理]
# 変更前のデータを呼び出し
# 現在の入力値と比較
# 消えているIDがあれば、対象エントリーのカスタムフィールドからIDを削除
# 追加されているIDがあれば、対象エントリーのカスタムフィールドに追加
# 再構築

# 配列の差集合抽出は以下を参照
# http://dev-man.seesaa.net/article/117885645.html

# IDが正しいか（数値かどうか）判定が必要

sub post_save_entry {
    my ($cb, $app, $obj, $org_obj) = @_;

    my $id = $obj->id;
    my $meta = get_meta($obj);
    my $relating = $meta->{'relatedentries'};
use Data::Dumper;
doLog(Dumper $obj);
    eval {
        if (defined($org_obj->id)) {
            my $org_meta = get_meta($org_obj);
            my $org_relating = $org_meta->{'relatedentries'};
            update_entry_connection($relating, $org_relating, $id);
        }
    };
    if ( $@ ) {
        save_entry_connection($relating, $id);
    }
}

sub update_entry_connection {
    my ($entry_ids_txt, $org_entry_ids_txt, $set_id) = @_;
    $entry_ids_txt =~ s/^,//;
    $org_entry_ids_txt =~ s/^,//;
    my @entry_ids = split(/,/, $entry_ids_txt);
    my @org_entry_ids = split(/,/, $org_entry_ids_txt);
doLog("引数: $entry_ids_txt / $org_entry_ids_txt");
    my $list_compare = List::Compare->new(\@entry_ids, \@org_entry_ids);

    # 追加するエントリーID
    my @add_entry_id = $list_compare->get_Lonly;

    # 削除するエントリーID
    my @delete_entry_id = $list_compare->get_Ronly;

    # 追加と削除は同時に発生しない
    foreach my $entry_id (@add_entry_id) {
        my $entry = MT::Entry->load($entry_id);
        my $meta;
        my $meta = get_meta($entry);
        my $field_txt = $meta->{'relatedentries'};
doLog("add $entry_id");
        $field_txt .= ",$entry_id";
        $meta->{'relatedentries'} = $field_txt;
        save_meta($entry, $meta);
        $entry->save();
    }

    foreach my $entry_id (@delete_entry_id) {
        my $entry = MT::Entry->load($entry_id);
        my $meta;
        my $meta = get_meta($entry);
        my $field_txt = $meta->{'relatedentries'};
doLog("delete $entry_id");
        $field_txt =~ s/,?\s?$entry_id//;
        $meta->{'relatedentries'} = $field_txt;
        save_meta($entry, $meta);
        $entry->save();
    }
}

sub save_entry_connection {
    my ($entry_ids_txt, $org_entry_ids_txt, $set_id) = @_;
    $entry_ids_txt=~ s/^,//;
    my @entry_ids = split(/,/, $entry_ids_txt);

    foreach my $entry_id (@entry_ids) {
        my $entry = MT::Entry->load($entry_id);
        my $meta;

        $meta->{'relatedentries'} = $set_id;
        save_meta($entry, $meta);
        $entry->save();
    }
}

sub doLog {
    my ($msg, $class) = @_;
    return unless defined($msg);

    require MT::Log;
    my $log = new MT::Log;
    $log->message($msg);
    $log->level(MT::Log::DEBUG());
    $log->class($class) if $class;
    $log->save or die $log->errstr;
}

1;