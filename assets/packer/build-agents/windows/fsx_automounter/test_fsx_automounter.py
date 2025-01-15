# tests fsx_automounter.py
# usage:
# 1. install pytest: `pip install pytest`
# 2. `python -m pytest`
from botocore.exceptions import BotoCoreError
from botocore.exceptions import ClientError
from botocore.exceptions import MetadataRetrievalError
from botocore.utils import IMDSFetcher
from fsx_automounter import get_instance_name, get_volumes_with_automount_tags
from fsx_automounter import main, get_instance_region, mount_fsx_volumes
from unittest.mock import MagicMock, patch, Mock
import boto3
import botocore.exceptions
import fsx_automounter
import platform
import pytest
import subprocess


def test_get_instance_name_empty_response():
    """
    Test get_instance_name when the IMDS response is empty.
    """
    with patch('fsx_automounter.IMDSFetcher') as mock_imds:
        mock_response = MagicMock()
        mock_response.text = ''
        mock_imds.return_value._get_request.return_value = mock_response
        
        result = get_instance_name()
        assert result == '', "Expected empty string when IMDS response is empty"


def test_get_instance_name_imds_error():
    """
    Test get_instance_name when IMDSFetcher raises an exception.
    """
    with patch('fsx_automounter.IMDSFetcher') as mock_imds:
        mock_imds.return_value._fetch_metadata_token.side_effect = BotoCoreError()
        with pytest.raises(BotoCoreError):
            get_instance_name()


def test_get_instance_name_network_error():
    """
    Test get_instance_name when a network error occurs during the IMDS request.
    """
    with patch('fsx_automounter.IMDSFetcher') as mock_imds:
        mock_imds.return_value._get_request.side_effect = ConnectionError()
        with pytest.raises(ConnectionError):
            get_instance_name()


def test_get_instance_name_returns_ec2_instance_name():
    """
    Test that get_instance_name returns the EC2 instance name from metadata
    """
    mock_response = Mock()
    mock_response.text = "test-instance-name\n"
    
    with patch.object(IMDSFetcher, '_get_request', return_value=mock_response) as mock_get_request:
        with patch.object(IMDSFetcher, '_fetch_metadata_token', return_value='mock-token'):
            result = get_instance_name()
    
    assert result == "test-instance-name"
    mock_get_request.assert_called_once_with("/latest/meta-data/tags/instance/Name", None, token='mock-token')


def test_get_instance_name_timeout():
    """
    Test get_instance_name when the IMDS request times out.
    """
    with patch('fsx_automounter.IMDSFetcher') as mock_imds:
        mock_imds.return_value._get_request.side_effect = TimeoutError()
        with pytest.raises(TimeoutError):
            get_instance_name()


def test_get_instance_name_whitespace_response():
    """
    Test get_instance_name when the IMDS response contains only whitespace.
    """
    with patch('fsx_automounter.IMDSFetcher') as mock_imds:
        mock_response = MagicMock()
        mock_response.text = '   \n\t  '
        mock_imds.return_value._get_request.return_value = mock_response
        
        result = get_instance_name()
        assert result == '', "Expected empty string when IMDS response contains only whitespace"


def test_get_instance_region_connection_error():
    """
    Test when there's a connection error to IMDS.
    """
    with patch.object(IMDSFetcher, '_get_request', side_effect=ConnectionError):
        with pytest.raises(botocore.utils._RetriesExceededError):
            get_instance_region()


def test_get_instance_region_returns_correct_region():
    """
    Test that get_instance_region returns the correct region from EC2 instance metadata.
    """
    # Mock the IMDSFetcher class and its methods
    with patch.object(IMDSFetcher, '_fetch_metadata_token', return_value='mock_token'):
        with patch.object(IMDSFetcher, '_get_request') as mock_get_request:
            # Set up the mock response
            mock_response = MagicMock()
            mock_response.text = '  us-west-2  '
            mock_get_request.return_value = mock_response

            # Call the function under test
            result = get_instance_region()

            # Assert that the function returns the expected region
            assert result == 'us-west-2'

            # Verify that _get_request was called with the correct arguments
            mock_get_request.assert_called_once_with(
                "/latest/meta-data/placement/region",
                None,
                token='mock_token'
            )


def test_get_instance_region_timeout():
    """
    Test when IMDS request times out.
    """
    with patch.object(IMDSFetcher, '_get_request', side_effect=TimeoutError):
        with pytest.raises(botocore.utils._RetriesExceededError):
            get_instance_region()


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_1(mock_instance):
    """
    Test get_volumes_with_automount_tags when volume has required tags and is of type OPENZFS
    """
    # Mock the boto3 client
    mock_client = Mock()
    mock_client.meta.region_name = 'us-west-2'

    # Mock the describe_volumes response
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-1234567890abcdef0',
            'VolumeType': 'OPENZFS',
            'FileSystemId': 'fs-1234567890abcdef0',
            'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-1234567890abcdef0',
            'OpenZFSConfiguration': {
                'VolumePath': '/fsx'
            }
        }]
    }

    # Mock the list_tags_for_resource response
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'test-instance'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'},
            {'Key': 'automount-fsx-volume-driveletter', 'Value': 'Z'}
        ]
    }

    # Call the function
    result = get_volumes_with_automount_tags(mock_client)

    # Assert the result
    assert len(result) == 1
    assert result[0]['Volume']['VolumeId'] == 'vol-1234567890abcdef0'
    assert result[0]['Name'] == 'test-volume'
    assert result[0]['DriveLetter'] == 'Z'
    assert result[0]['DNS'] == 'fs-1234567890abcdef0.fsx.us-west-2.amazonaws.com'
    assert result[0]['VolumeType'] == 'OPENZFS'
    assert result[0]['VolumePath'] == '/fsx'

    # Verify that the mock methods were called
    mock_client.describe_volumes.assert_called_once()
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-1234567890abcdef0'
    )


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_2(mock_instance):
    """
    Test get_volumes_with_automount_tags when volume type is not OPENZFS
    """
    # Mock the client
    mock_client = Mock()

    # Mock the describe_volumes method with correct FSx volume structure
    mock_client.describe_volumes.return_value = {
        'Volumes': [
            {
                'VolumeId': 'vol-123456',
                'VolumeType': 'gp2',
                'FileSystemId': 'fs-123456',  # Add FileSystemId
                'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'  # Add ResourceARN
            }
        ]
    }

    # Mock the list_tags_for_resource method
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'test-instance'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'},
            {'Key': 'automount-fsx-volume-driveletter', 'Value': 'Y'}
        ]
    }

    # Call the function
    result = get_volumes_with_automount_tags(mock_client)

    # Assert that the result is empty (since it's not an OPENZFS volume)
    assert len(result) == 0

    # Verify the mock calls
    mock_client.describe_volumes.assert_called_once()


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_3(mock_instance):
    """
    Test get_volumes_with_automount_tags when volume has required tags but instance name doesn't match.
    """
    # Mock the boto3 client
    mock_client = Mock()

    # Set up mock return values
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-123456',
            'VolumeType': 'OPENZFS',
            'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
        }]
    }
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'other-instance'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'}
        ]
    }

    # Call the function under test
    result = get_volumes_with_automount_tags(mock_client)

    # Assert the results
    assert result == [], "Expected an empty list when instance name doesn't match"

    # Verify the mock calls
    mock_client.describe_volumes.assert_called_once()
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
    )
    mock_instance.assert_called_once()


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_4(mock_instance):
    """
    Test get_volumes_with_automount_tags when volume has no automount tags.
    """
    # Mock the boto3 client
    mock_client = Mock()
    
    # Mock the describe_volumes response
    mock_client.describe_volumes.return_value = {
        'Volumes': [
            {
                'VolumeId': 'vol-12345',
                'VolumeType': 'OPENZFS',
                'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-12345'
            }
        ]
    }
    
    # Mock the list_tags_for_resource response
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'other-tag', 'Value': 'some-value'}
        ]
    }
    
    # Call the function under test
    result = get_volumes_with_automount_tags(mock_client)
    
    # Assert that the result is an empty list
    assert result == []
    
    # Verify that describe_volumes was called
    mock_client.describe_volumes.assert_called_once()
    
    # Verify that list_tags_for_resource was called with the correct ARN
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-12345'
    )


@patch('fsx_automounter.get_instance_name', return_value='instance-1')
def test_get_volumes_with_automount_tags_client_error(mock_instance):
    """
    Test get_volumes_with_automount_tags when ClientError is raised
    """
    mock_client = Mock()
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-12345',
            'VolumeType': 'OPENZFS',
            'ResourceARN': 'arn:aws:ec2:us-west-2:123456789012:volume/vol-12345'
        }]
    }
    mock_client.list_tags_for_resource.side_effect = ClientError(
        {'Error': {'Code': 'AccessDenied'}},
        'ListTagsForResource'
    )

    result = get_volumes_with_automount_tags(mock_client)
    assert result == [], "Expected empty list when ClientError is raised"


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_client_error_2(mock_instance):
    """
    Test get_volumes_with_automount_tags when ClientError occurs while listing tags.
    """
    # Mock the boto3 client
    mock_client = Mock()
    
    # Set up mock return values
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-123456',
            'VolumeType': 'OPENZFS',
            'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
        }]
    }
    mock_client.list_tags_for_resource.side_effect = ClientError(
        error_response={'Error': {'Code': 'AccessDenied'}},
        operation_name='ListTagsForResource'
    )

    # Call the function under test
    result = get_volumes_with_automount_tags(mock_client)

    # Assert the results
    assert result == [], "Expected an empty list when ClientError occurs"

    # Verify the mock calls
    mock_client.describe_volumes.assert_called_once()
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
    )


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_empty_input(mock_instance):
    """
    Test get_volumes_with_automount_tags with empty input
    """
    mock_client = Mock()
    mock_client.describe_volumes.return_value = {'Volumes': []}
    
    result = get_volumes_with_automount_tags(mock_client)
    assert result == [], "Expected empty list for empty input"


@patch('fsx_automounter.get_instance_name', return_value='instance-1')
def test_get_volumes_with_automount_tags_instance_name_mismatch(mock_instance):
    """
    Test get_volumes_with_automount_tags when instance name doesn't match
    """
    mock_client = Mock()
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-12345',
            'VolumeType': 'OPENZFS',
            'ResourceARN': 'arn:aws:ec2:us-west-2:123456789012:volume/vol-12345'
        }]
    }
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'instance-2'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'}
        ]
    }

    result = get_volumes_with_automount_tags(mock_client)
    assert result == [], "Expected empty list when instance name doesn't match"


@patch('fsx_automounter.get_instance_name', return_value='instance-1')
def test_get_volumes_with_automount_tags_invalid_volume_type(mock_instance):
    """
    Test get_volumes_with_automount_tags with an unsupported volume type
    """
    mock_client = Mock()
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-12345',
            'VolumeType': 'UNSUPPORTED',
            'ResourceARN': 'arn:aws:ec2:us-west-2:123456789012:volume/vol-12345'
        }]
    }
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'instance-1'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'}
        ]
    }

    result = get_volumes_with_automount_tags(mock_client)
    assert result == [], "Expected empty list for unsupported volume type"


@patch('fsx_automounter.get_instance_name', return_value='instance-1')
def test_get_volumes_with_automount_tags_missing_required_tags(mock_instance):
    """
    Test get_volumes_with_automount_tags with missing required tags
    """
    mock_client = Mock()
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-12345',
            'VolumeType': 'OPENZFS',
            'ResourceARN': 'arn:aws:ec2:us-west-2:123456789012:volume/vol-12345'
        }]
    }
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'instance-1'}
        ]
    }

    result = get_volumes_with_automount_tags(mock_client)
    assert result == [], "Expected empty list when required tags are missing"


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_unsupported_volume_type(mock_instance):
    """
    Test get_volumes_with_automount_tags when volume type is not supported.
    """
    # Mock the boto3 client
    mock_client = Mock()
    
    # Set up mock return values
    mock_client.describe_volumes.return_value = {
        'Volumes': [{
            'VolumeId': 'vol-123456',
            'VolumeType': 'UNSUPPORTED',
            'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
        }]
    }
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'test-instance'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'}
        ]
    }

    # Call the function under test
    result = get_volumes_with_automount_tags(mock_client)

    # Assert the results
    assert result == [], "Expected an empty list for unsupported volume type"

    # Verify the mock calls
    mock_client.describe_volumes.assert_called_once()
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-123456'
    )
    mock_instance.assert_called_once()


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
def test_get_volumes_with_automount_tags_unsupported_volume_type_2(mock_instance):
    """
    Test get_volumes_with_automount_tags with an unsupported volume type.
    """
    # Mock the boto3 client
    mock_client = Mock()
    
    # Mock the describe_volumes response
    mock_client.describe_volumes.return_value = {
        'Volumes': [
            {
                'VolumeId': 'vol-12345',
                'VolumeType': 'UNSUPPORTED',
                'ResourceARN': 'arn:aws:fsx:us-west-2:123456789012:volume/vol-12345'
            }
        ]
    }
    
    # Mock the list_tags_for_resource response
    mock_client.list_tags_for_resource.return_value = {
        'Tags': [
            {'Key': 'automount-fsx-volume-on', 'Value': 'test-instance'},
            {'Key': 'automount-fsx-volume-name', 'Value': 'test-volume'}
        ]
    }
    
    # Call the function under test
    result = get_volumes_with_automount_tags(mock_client)
    
    # Assert that the result is an empty list
    assert result == []
    
    # Verify that describe_volumes was called
    mock_client.describe_volumes.assert_called_once()
    
    # Verify that list_tags_for_resource was called with the correct ARN
    mock_client.list_tags_for_resource.assert_called_once_with(
        ResourceARN='arn:aws:fsx:us-west-2:123456789012:volume/vol-12345'
    )


@patch('fsx_automounter.get_instance_region', return_value='us-west-2')
def test_main_boto3_client_creation_failure(mock_region):
    """
    Test that main handles failure to create boto3 client.
    """
    with patch('boto3.client', side_effect=botocore.exceptions.BotoCoreError):
        with pytest.raises(botocore.exceptions.BotoCoreError):
            main()


@patch('fsx_automounter.get_instance_region', return_value='us-west-2')
def test_main_mount_fsx_volumes_failure(mock_region):
    """
    Test that main handles failure in mount_fsx_volumes.
    """
    with patch('boto3.client', return_value=MagicMock()):
        with patch('fsx_automounter.mount_fsx_volumes', side_effect=Exception("Mount failed")):
            with pytest.raises(Exception, match="Mount failed"):
                main()


@patch('fsx_automounter.get_instance_region', return_value='us-west-2')
def test_main_no_volumes_to_mount(mock_region):
    """
    Test main when there are no volumes to mount.
    """
    with patch('boto3.client', return_value=MagicMock()):
        with patch('fsx_automounter.mount_fsx_volumes', return_value=None):
            assert main() == 0


def test_main_region_fetch_failure():
    """
    Test that main handles failure to fetch instance region.
    """
    with patch('fsx_automounter.get_instance_region', side_effect=botocore.exceptions.BotoCoreError):
        with pytest.raises(botocore.exceptions.BotoCoreError):
            main()


@patch('fsx_automounter.get_instance_region', return_value='us-west-2')
@patch('fsx_automounter.mount_fsx_volumes')
def test_main_calls_mount(mock_mount_volumes, mock_get_region):
    """
    Test that the main function sets up fsx client with an automatically determined region and calls mock_mount_volumes
    """
    with patch('boto3.client') as mock_boto3_client:
        mock_client = MagicMock()
        mock_boto3_client.return_value = mock_client
        
        result = main()
        
        mock_get_region.assert_called_once()
        mock_boto3_client.assert_called_once_with('fsx', region_name='us-west-2')
        mock_mount_volumes.assert_called_once_with(mock_client)
        assert result == 0


@patch('fsx_automounter.get_instance_region')
@patch('fsx_automounter.mount_fsx_volumes')
def test_main_calls_mount_2(mock_mount_volumes, mock_get_region):
    """
    Test that the main function sets up fsx client with a provided region and calls mock_mount_volumes
    """
    with patch('boto3.client') as mock_boto3_client:
        mock_client = MagicMock()
        mock_boto3_client.return_value = mock_client
        
        result = main('eu-north-1')
        
        mock_get_region.assert_not_called()
        mock_boto3_client.assert_called_once_with('fsx', region_name='eu-north-1')
        mock_mount_volumes.assert_called_once_with(mock_client)
        assert result == 0


@patch('platform.system', return_value='Windows')
@patch('subprocess.run', return_value=MagicMock(returncode=1))
@patch('builtins.print')
def test_mount_fsx_volumes_2(mock_print, mock_run, mock_platform):
    """
    Test mount_fsx_volumes when volume type is OPENZFS, platform is Windows, 
    drive letter is specified, but the mount command fails.
    """
    # Mock the client
    mock_client = MagicMock()

    # Mock get_volumes_with_automount_tags to return a test volume
    test_volume = {
        'VolumeType': 'OPENZFS',
        'Name': 'TestVolume',
        'DriveLetter': 'Z',
        'DNS': 'fs-test.fsx.us-west-2.amazonaws.com',
        'VolumePath': '/fsx'
    }
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=[test_volume]):
        mount_fsx_volumes(mock_client)

    # Assert that the mount command was called with the correct arguments
    mock_run.assert_called_once_with([
        'powershell.exe', '-Command',
        'New-PSDrive -Persist -Name Z -PSProvider FileSystem -Root \\\\fs-test.fsx.us-west-2.amazonaws.com\\fsx'
    ])

    # Assert that the correct error messages were printed
    mock_print.assert_any_call("Failed to mount volume 'TestVolume'")


@patch('platform.system', return_value='Windows')
@patch('subprocess.run', return_value=MagicMock(returncode=0))
def test_mount_fsx_volumes_3(mock_run, mock_platform):
    """
    Test mount_fsx_volumes when volume type is OPENZFS, platform is Windows, drive letter is specified, and mount command succeeds.
    """
    # Mock the boto3 client
    mock_client = Mock()

    # Mock the get_volumes_with_automount_tags function
    mock_volume_info = [{
        'VolumeType': 'OPENZFS',
        'Name': 'TestVolume',
        'DriveLetter': 'Z',
        'DNS': 'fs-12345678.fsx.us-west-2.amazonaws.com',
        'VolumePath': '/fsx'
    }]
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=mock_volume_info):
        # Call the function under test
        mount_fsx_volumes(mock_client)

    # Assert that subprocess.run was called with the correct arguments
    expected_cmd = ['powershell.exe', '-Command', 'New-PSDrive -Persist -Name Z -PSProvider FileSystem -Root \\\\fs-12345678.fsx.us-west-2.amazonaws.com\\fsx']
    mock_run.assert_called_once_with(expected_cmd)


@patch('platform.system', return_value='Linux')
@patch('subprocess.run', return_value=MagicMock(returncode=0))
def test_mount_fsx_volumes_4(mock_run, mock_platform):
    """
    Test mount_fsx_volumes when volume type is OPENZFS and platform is not Windows.
    """
    # Mock the boto3 client
    mock_client = MagicMock()

    # Mock get_volumes_with_automount_tags to return a volume with OPENZFS type
    mock_volume_info = {
        'VolumeType': 'OPENZFS',
        'Name': 'test_volume',
        'DNS': 'fs-123456.fsx.us-west-2.amazonaws.com',
        'VolumePath': '/fsx'
    }
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=[mock_volume_info]):
        mount_fsx_volumes(mock_client)

    # Assert that subprocess.run was not called (as it's not Windows)
    mock_run.assert_not_called()


@patch('fsx_automounter.get_instance_name', return_value='test-instance')
@patch('subprocess.run', return_value=MagicMock(returncode=0))
def test_mount_fsx_volumes_no_volumes(mock_run, mock_instance):
    """
    Test mount_fsx_volumes when no volumes are returned
    """
    mock_client = MagicMock()
    mock_client.describe_volumes.return_value = {'Volumes': []}
    
    # This should not raise an exception, but also should not mount anything
    mount_fsx_volumes(mock_client)
    mock_run.assert_not_called()


@patch('builtins.print')
def test_mount_fsx_volumes_unsupported_type(mock_print):
    """
    Test mount_fsx_volumes when volume type is not supported.
    """
    # Mock the boto3 client
    mock_client = Mock()

    # Mock the get_volumes_with_automount_tags function
    mock_volume_info = [{
        'VolumeType': 'UNSUPPORTED',
        'Name': 'TestVolume'
    }]
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=mock_volume_info):
        # Call the function under test
        mount_fsx_volumes(mock_client)

    # Assert that the correct message was printed
    mock_print.assert_called_once_with("Currently not supported: volumeType UNSUPPORTED")


@patch('builtins.print')
def test_mount_fsx_volumes_unsupported_volume_type(mock_print):
    """
    Test mount_fsx_volumes when volume type is not OPENZFS
    """
    # Mock the client
    mock_client = Mock()

    # Mock get_volumes_with_automount_tags to return a volume with unsupported type
    mock_volume_info = {
        'VolumeType': 'UNSUPPORTED_TYPE',
        'Name': 'TestVolume'
    }
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=[mock_volume_info]):
        mount_fsx_volumes(mock_client)

    # Assert that the correct message was printed
    mock_print.assert_called_with("Currently not supported: volumeType UNSUPPORTED_TYPE")


@patch('platform.system', return_value='Windows')
@patch('subprocess.run', return_value=MagicMock(returncode=1))
@patch('builtins.print')
def test_mount_fsx_volumes_windows_mount_failure(mock_print, mock_run, mock_platform):
    """
    Test mount_fsx_volumes on Windows when the mount command fails.
    Should log a warning, but not throw.
    """
    mock_client = Mock()
    mock_volume_info = [{
        'VolumeType': 'OPENZFS',
        'Name': 'TestVolume',
        'DriveLetter': 'T',
        'DNS': 'fs-12345678.fsx.us-west-2.amazonaws.com',
        'VolumePath': '/fsx'
    }]

    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=mock_volume_info):
        mount_fsx_volumes(mock_client)
    # Check that the error message is printed
    mock_print.assert_any_call("Failed to mount volume 'TestVolume'")


@patch('platform.system', return_value='Windows')
@patch('subprocess.run', return_value=MagicMock())
@patch('builtins.print')
def test_mount_fsx_volumes_windows_no_drive_letter(mock_print, mock_run, mock_platform):
    """
    Test mount_fsx_volumes when volume type is OPENZFS, platform is Windows, and no drive letter is specified.
    Should log a warning, but not throw.
    """
    # Mock the boto3 client
    mock_client = Mock()

    # Mock the get_volumes_with_automount_tags function
    mock_volume_info = [{
        'VolumeType': 'OPENZFS',
        'Name': 'TestVolume',
        'DriveLetter': None,
        'DNS': 'fs-12345678.fsx.us-west-2.amazonaws.com',
        'VolumePath': '/fsx'
    }]
    with patch('fsx_automounter.get_volumes_with_automount_tags', return_value=mock_volume_info):
        mount_fsx_volumes(mock_client)

    # Check that the error message is printed
    mock_print.assert_any_call("Failed to mount volume 'TestVolume'")
    assert "No drive letter specified for volume 'TestVolume'" in str(mock_print.call_args.args[0])
    # Assert that the subprocess.run was not called
    mock_run.assert_not_called()
