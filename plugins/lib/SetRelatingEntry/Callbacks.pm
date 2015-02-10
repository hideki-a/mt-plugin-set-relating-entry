# ベース: https://github.com/movabletype/Documentation/wiki/Japanese-plugin-dev-3-2
# カスタムフィールド参考: http://junnama.alfasado.net/online/2008/02/post_152.html
package SetRelatingEntry::Callbacks;
use strict;
use List::Compare;
use MT::WeblogPublisher;
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
# 可能であればIDを降順に

sub post_save_entry {
    my ($cb, $app, $obj, $org_obj) = @_;

    my $blog_id = 'blog:' . $obj->blog_id;
    my $plugin = MT->component('SetRelatingEntry');
    my $cf_basename = $plugin->get_config_value('relating_entry_basename', $blog_id);
    return unless $plugin->get_config_value('relating_entry_isuse', $blog_id);

    my $id = $obj->id;
    my $meta = get_meta($obj);
    my $relating = $meta->{$cf_basename};

    if (defined($org_obj->id)) {
        my $org_meta = get_meta($org_obj);
        my $org_relating = $org_meta->{$cf_basename};
        update_entry_connection($relating, $org_relating, $id, $cf_basename);
    } else {
        save_entry_connection($relating, $id, $cf_basename);
    }
}

sub update_entry_connection {
    my ($entry_ids_txt, $org_entry_ids_txt, $set_id, $cf_basename) = @_;
    my $pub = MT::WeblogPublisher->new;

    $entry_ids_txt =~ s/^,//;
    $org_entry_ids_txt =~ s/^,//;
    my @entry_ids = split(/,/, $entry_ids_txt);
    my @org_entry_ids = split(/,/, $org_entry_ids_txt);

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
        my $field_txt = $meta->{$cf_basename};

        $field_txt .= ",$set_id";
        $meta->{$cf_basename} = $field_txt;
        save_meta($entry, $meta);
        $entry->save();
        if ($entry->status == MT::Entry::RELEASE()) {
            $pub->rebuild_entry( Entry => $entry );
        }
    }

    foreach my $entry_id (@delete_entry_id) {
        my $entry = MT::Entry->load($entry_id);
        my $meta;
        my $meta = get_meta($entry);
        my $field_txt = $meta->{$cf_basename};

        $field_txt =~ s/,?\s?$set_id//;
        $meta->{$cf_basename} = $field_txt;
        save_meta($entry, $meta);
        $entry->save();
        if ($entry->status == MT::Entry::RELEASE()) {
            $pub->rebuild_entry( Entry => $entry );
        }
    }
}

sub save_entry_connection {
    my ($entry_ids_txt, $set_id, $cf_basename) = @_;
    my $pub = MT::WeblogPublisher->new;

    $entry_ids_txt=~ s/^,//;
    my @entry_ids = split(/,/, $entry_ids_txt);

    foreach my $entry_id (@entry_ids) {
        my $entry = MT::Entry->load($entry_id);
        my $meta;
        my $meta = get_meta($entry);
        my $field_txt = $meta->{$cf_basename};

        $field_txt .= ",$set_id";
        $meta->{$cf_basename} = $field_txt;
        save_meta($entry, $meta);
        $entry->save();
        if ($entry->status == MT::Entry::RELEASE()) {
            $pub->rebuild_entry( Entry => $entry );
        }
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